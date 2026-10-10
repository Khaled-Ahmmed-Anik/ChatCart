class ProcessWhatsappEventJob < ApplicationJob
  queue_as :whatsapp_inbound

  retry_on ActiveRecord::Deadlocked, wait: :polynomially_longer, attempts: 5

  def perform(webhook_event)
    return unless webhook_event.event_type == "customer_text"
    return skip_inactive_business(webhook_event) unless webhook_event.business.active?
    return enqueue_existing_delivery(webhook_event) if webhook_event.whatsapp_delivery.present?
    return if webhook_event.status == "processed"

    processing = process_events(webhook_event)
    return if processing.blank?

    SendWhatsappReplyJob.perform_later(processing.fetch(:delivery)) if processing[:delivery]
  rescue StandardError => error
    webhook_event.update!(status: "failed", last_error: error.message) if webhook_event&.persisted?
    MessengerSafeLogger.error(
      "whatsapp_processing_failed",
      message_id: webhook_event&.external_event_id,
      sender_reference: MessagingSafeIdentifier.call(webhook_event&.sender_id),
      job_id: job_id,
      error_class: error.class.name
    )
    raise
  end

  private

  def skip_inactive_business(webhook_event)
    webhook_event.update!(status: "ignored", processed_at: Time.current, last_error: "business_inactive")
  end

  def enqueue_existing_delivery(webhook_event)
    delivery = webhook_event.whatsapp_delivery
    webhook_event.update!(status: "processed", processed_at: webhook_event.processed_at || Time.current, last_error: nil)
    SendWhatsappReplyJob.perform_later(delivery) unless delivery.status.in?(%w[sent delivered read failed skipped])
  end

  def process_events(webhook_event)
    result = nil
    delivery = nil

    WhatsappWebhookEvent.transaction do
      events = pending_events(webhook_event).lock.to_a
      return if events.empty?

      events.each { |event| event.update!(status: "processing", last_error: nil) }
      last_event = events.last
      result = CustomerMessageRecorder.new(
        business: webhook_event.business,
        channel: "whatsapp",
        external_customer_id: webhook_event.sender_id,
        content: combined_text(events),
        metadata: combined_metadata(events)
      ).record
      if result.bot_reply
        delivery = WhatsappDelivery.create!(
          whatsapp_webhook_event: last_event,
          message: result.bot_reply,
          recipient_id: webhook_event.sender_id,
          phone_number_id: webhook_event.phone_number_id
        )
      end
      events.each { |event| event.update!(status: "processed", processed_at: Time.current, last_error: nil) }
    end

    { result: result, delivery: delivery }
  end

  def pending_events(webhook_event)
    WhatsappWebhookEvent.where(
      business: webhook_event.business,
      sender_id: webhook_event.sender_id,
      phone_number_id: webhook_event.phone_number_id,
      event_type: "customer_text",
      status: %w[received failed]
    ).where("created_at <= ?", Time.current).order(:created_at, :id)
  end

  def combined_text(events)
    events.filter_map { |event| event.payload.dig("text", "body").presence }.join("\n")
  end

  def combined_metadata(events)
    events.last.payload.merge(
      "batched_message_ids" => events.filter_map(&:external_event_id),
      "batched_message_count" => events.size,
      "phone_number_id" => events.last.phone_number_id
    )
  end
end
