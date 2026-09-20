class ProcessMessengerEventJob < ApplicationJob
  queue_as :messenger_inbound

  retry_on ActiveRecord::Deadlocked, wait: :polynomially_longer, attempts: 5

  def perform(webhook_event)
    return unless webhook_event.event_type == "customer_text"
    return enqueue_existing_delivery(webhook_event) if webhook_event.messenger_delivery.present?
    return if webhook_event.status == "processed"

    result = process_events(webhook_event)
    return if result.blank?

    SendMessengerReplyJob.perform_later(result.fetch(:delivery)) if result[:delivery]
    log_processed(result.fetch(:webhook_event), result)
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

  def process_events(webhook_event)
    result = nil
    delivery = nil
    processed_event = nil

    MessengerWebhookEvent.transaction do
      events = pending_customer_events(webhook_event).lock.to_a
      return if events.empty?

      events.each { |event| event.update!(status: "processing", last_error: nil) }
      processed_event = events.last
      result = CustomerMessageRecorder.new(
        business: webhook_event.business,
        channel: "facebook",
        external_customer_id: webhook_event.sender_id,
        content: combined_text(events),
        metadata: combined_metadata(events)
      ).record
      if result.bot_reply
        delivery = MessengerDelivery.create!(
          messenger_webhook_event: processed_event,
          message: result.bot_reply,
          recipient_id: webhook_event.sender_id
        )
      end
      events.each { |event| event.update!(status: "processed", processed_at: Time.current, last_error: nil) }
    end

    { result: result, delivery: delivery, webhook_event: processed_event }
  end

  def pending_customer_events(webhook_event)
    MessengerWebhookEvent.where(
      business: webhook_event.business,
      sender_id: webhook_event.sender_id,
      event_type: "customer_text",
      status: %w[received failed]
    ).where("created_at <= ?", Time.current).order(:created_at, :id)
  end

  def combined_text(events)
    events.filter_map { |event| event.payload.dig("message", "text").presence }.join("\n")
  end

  def combined_metadata(events)
    events.last.payload.merge(
      "batched_message_ids" => events.filter_map(&:external_event_id),
      "batched_message_count" => events.size
    )
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
