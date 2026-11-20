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
    result = delivery.with_lock { deliver_parts(delivery) }
    raise TemporaryDeliveryError, result.error || "Messenger temporary failure" if result&.retryable
  end

  private

  def deliver_parts(delivery)
    return if delivery.status == "delivered"
    return skip_inactive_business(delivery) unless delivery.messenger_webhook_event.business.reload.active?
    if delivery.messenger_webhook_event.business.reload.blocks_automated_reply?(delivery.message)
      delivery.update!(status: "skipped", last_error: "business_automation_paused")
      return
    end

    delivery.increment!(:attempts)
    message = delivery.message
    attachments = Array(message.metadata["attachments"]).first(Constants::ProductMedia::MAX_ATTACHMENTS)
    parts = [ nil, *attachments ]
    cursor = message.metadata.fetch("messenger_parts_sent", 0).to_i
    result = nil
    parts.each_with_index do |attachment, index|
      next if index < cursor
      if delivery.messenger_webhook_event.business.reload.blocks_automated_reply?(message)
        delivery.update!(status: "skipped", last_error: "business_automation_paused")
        return
      end

      arguments = { recipient_id: delivery.recipient_id, content: message.content, page_access_token: page_access_token_for(delivery) }
      arguments[:attachment] = attachment if attachment
      result = MessengerReplySender.new(**arguments).deliver
      break unless result.delivered

      message.update!(metadata: message.metadata.merge("messenger_parts_sent" => index + 1))
    end
    if result.nil?
      delivery.update!(status: "delivered", delivered_at: Time.current, last_error: nil)
      return
    end

    persist_result(delivery, result)
    log_result(delivery)

    result
  end

  def skip_inactive_business(delivery)
    delivery.update!(status: "skipped", last_error: "business_inactive")
    nil
  end

  def page_access_token_for(delivery)
    MessengerPageConnection.for_event(delivery.messenger_webhook_event)&.access_token
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
