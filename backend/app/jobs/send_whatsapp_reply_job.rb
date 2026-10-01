class SendWhatsappReplyJob < ApplicationJob
  class TemporaryDeliveryError < StandardError; end

  queue_as :whatsapp_outbound

  retry_on TemporaryDeliveryError, wait: :polynomially_longer, attempts: 5 do |job, error|
    delivery = job.arguments.first
    delivery.update!(status: "failed", last_error: error.message)
    SendWhatsappReplyJob.log_delivery(delivery, job.job_id, "whatsapp_delivery_failed")
  end

  def perform(delivery)
    return if delivery.status.in?(%w[sent delivered read])
    return skip_inactive_business(delivery) unless delivery.whatsapp_webhook_event.business.active?

    delivery.increment!(:attempts)
    result = WhatsappReplySender.new(
      recipient_id: delivery.recipient_id,
      phone_number_id: delivery.phone_number_id,
      content: delivery.message.content,
      access_token: access_token_for(delivery)
    ).deliver
    persist_result(delivery, result)
    self.class.log_delivery(delivery, job_id, "whatsapp_delivery_#{delivery.status}")
    raise TemporaryDeliveryError, result.error || "WhatsApp temporary failure" if result.retryable
  end

  def self.log_delivery(delivery, job_id, event)
    MessengerSafeLogger.info(
      event,
      message_id: delivery.whatsapp_webhook_event.external_event_id,
      sender_reference: MessagingSafeIdentifier.call(delivery.recipient_id),
      conversation_id: delivery.message.conversation_id,
      job_id: job_id,
      delivery_id: delivery.id,
      delivery_status: delivery.status,
      attempts: delivery.attempts,
      response_code: delivery.response_code
    )
  end

  private

  def skip_inactive_business(delivery)
    delivery.update!(status: "skipped", last_error: "business_inactive")
  end

  def access_token_for(delivery)
    business = delivery.whatsapp_webhook_event.business
    business.channel_connections.active.find_by(channel: "whatsapp")&.access_token || ENV["WHATSAPP_ACCESS_TOKEN"]
  end

  def persist_result(delivery, result)
    status = if result.delivered
      "sent"
    elsif result.skipped
      "skipped"
    elsif result.retryable
      "retrying"
    else
      "failed"
    end
    delivery.update!(
      status: status,
      response_code: result.status,
      response_body: result.response_body || {},
      external_message_id: result.external_message_id,
      last_error: result.error,
      delivered_at: nil
    )
  end
end
