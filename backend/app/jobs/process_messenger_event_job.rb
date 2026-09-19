class ProcessMessengerEventJob < ApplicationJob
  queue_as :messenger_inbound

  retry_on ActiveRecord::Deadlocked, wait: :polynomially_longer, attempts: 5

  def perform(webhook_event)
    return unless webhook_event.event_type == "customer_text"
    return enqueue_existing_delivery(webhook_event) if webhook_event.messenger_delivery.present?

    webhook_event.update!(status: "processing", last_error: nil)
    result = process_event(webhook_event)

    SendMessengerReplyJob.perform_later(result.fetch(:delivery))
    log_processed(webhook_event, result)
  rescue StandardError => error
    webhook_event.update!(status: "failed", last_error: error.message) if webhook_event&.persisted?
    MessengerSafeLogger.error(
      "processing_failed",
      messenger_message_id: webhook_event&.external_event_id,
      sender_id: webhook_event&.sender_id,
      job_id: job_id,
      error_class: error.class.name
    )
    raise
  end

  private

  def enqueue_existing_delivery(webhook_event)
    delivery = webhook_event.messenger_delivery
    webhook_event.update!(status: "processed", processed_at: webhook_event.processed_at || Time.current, last_error: nil)
    SendMessengerReplyJob.perform_later(delivery) unless delivery.status.in?(%w[delivered failed skipped])
  end

  def process_event(webhook_event)
    result = nil
    delivery = nil

    MessengerWebhookEvent.transaction do
      result = CustomerMessageRecorder.new(
        channel: "facebook",
        external_customer_id: webhook_event.sender_id,
        content: webhook_event.payload.dig("message", "text"),
        metadata: webhook_event.payload
      ).record
      delivery = MessengerDelivery.create!(
        messenger_webhook_event: webhook_event,
        message: result.bot_reply,
        recipient_id: webhook_event.sender_id
      )
      webhook_event.update!(status: "processed", processed_at: Time.current, last_error: nil)
    end

    { result: result, delivery: delivery }
  end

  def log_processed(webhook_event, processing)
    MessengerSafeLogger.info(
      "processed",
      messenger_message_id: webhook_event.external_event_id,
      sender_id: webhook_event.sender_id,
      conversation_id: processing.dig(:result, :conversation).id,
      job_id: job_id
    )
  end
end
