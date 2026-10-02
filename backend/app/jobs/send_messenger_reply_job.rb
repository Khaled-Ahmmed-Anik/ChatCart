class SendMessengerReplyJob < ApplicationJob
  class TemporaryDeliveryError < StandardError; end

  queue_as :messenger_outbound

  retry_on TemporaryDeliveryError, wait: :polynomially_longer, attempts: 5 do |job, error|
    delivery = job.arguments.first
    delivery.update!(status: "failed", last_error: error.message)
    MessengerSafeLogger.error(
      "delivery_failed",
      messenger_message_id: delivery.messenger_webhook_event.external_event_id,
      sender_id: delivery.recipient_id,
      conversation_id: delivery.message.conversation_id,
      job_id: job.job_id,
      delivery_id: delivery.id,
      delivery_status: delivery.status,
      attempts: delivery.attempts,
      response_code: delivery.response_code
    )
  end

  def perform(delivery)
    return if delivery.status == "delivered"
    return skip_inactive_business(delivery) unless delivery.messenger_webhook_event.business.active?

    delivery.increment!(:attempts)
    result = MessengerReplySender.new(
      recipient_id: delivery.recipient_id,
      content: delivery.message.content,
      page_access_token: page_access_token_for(delivery)
    ).deliver

    persist_result(delivery, result)
    log_result(delivery)

    raise TemporaryDeliveryError, result.error || "Messenger temporary failure" if result.retryable
  end

  private

  def skip_inactive_business(delivery)
    delivery.update!(status: "skipped", last_error: "business_inactive")
  end

  def page_access_token_for(delivery)
    business = delivery.messenger_webhook_event.business
    business.channel_connections.active.find_by(channel: "facebook")&.access_token || ENV["MESSENGER_PAGE_ACCESS_TOKEN"]
  end

  def persist_result(delivery, result)
    attributes = {
      response_code: result.status,
      last_error: result.error,
      delivered_at: result.delivered ? Time.current : nil
    }
    attributes[:status] = if result.delivered
      "delivered"
    elsif result.skipped
      "skipped"
    elsif result.retryable
      "retrying"
    else
      "failed"
    end

    delivery.update!(attributes)
  end

  def log_result(delivery)
    MessengerSafeLogger.info(
      "delivery_#{delivery.status}",
      messenger_message_id: delivery.messenger_webhook_event.external_event_id,
      sender_id: delivery.recipient_id,
      conversation_id: delivery.message.conversation_id,
      job_id: job_id,
      delivery_id: delivery.id,
      delivery_status: delivery.status,
      attempts: delivery.attempts,
      response_code: delivery.response_code
    )
  end
end
