require "test_helper"

class SendWhatsappReplyJobTest < ActiveJob::TestCase
  test "records a WhatsApp message as sent until a status webhook arrives" do
    delivery = create_delivery
    result = WhatsappReplySender::Result.new(
      delivered: true, skipped: false, retryable: false, status: 200,
      response_body: { "messages" => [ { "id" => "wamid.sent-1" } ] },
      external_message_id: "wamid.sent-1", error: nil
    )

    with_sender_result(result) { SendWhatsappReplyJob.perform_now(delivery) }

    delivery.reload
    assert_equal "sent", delivery.status
    assert_equal 1, delivery.attempts
    assert_equal "wamid.sent-1", delivery.external_message_id
    assert_nil delivery.delivered_at
  end

  test "records a permanent WhatsApp failure without retrying" do
    delivery = create_delivery
    result = WhatsappReplySender::Result.new(
      delivered: false, skipped: false, retryable: false, status: 400,
      response_body: { "error" => {} }, external_message_id: nil,
      error: "WhatsApp API returned HTTP 400"
    )

    assert_no_enqueued_jobs only: SendWhatsappReplyJob do
      with_sender_result(result) { SendWhatsappReplyJob.perform_now(delivery) }
    end

    assert_equal "failed", delivery.reload.status
    assert_equal 400, delivery.response_code
  end

  test "records a retryable WhatsApp failure and schedules retry" do
    delivery = create_delivery
    result = WhatsappReplySender::Result.new(
      delivered: false, skipped: false, retryable: true, status: 503,
      response_body: { "error" => {} }, external_message_id: nil,
      error: "WhatsApp API returned HTTP 503"
    )

    assert_enqueued_with(job: SendWhatsappReplyJob) do
      with_sender_result(result) { SendWhatsappReplyJob.perform_now(delivery) }
    end

    assert_equal "retrying", delivery.reload.status
  end

  private

  def create_delivery
    conversation = Conversation.create!(channel: "whatsapp", external_customer_id: "8801712345678")
    message = conversation.messages.create!(sender_type: :bot, content: "Hello")
    event = WhatsappWebhookEvent.create!(
      business: conversation.business,
      event_type: "customer_text",
      external_event_id: SecureRandom.uuid,
      sender_id: "8801712345678",
      phone_number_id: "phone-1",
      payload: { text: { body: "Hi" } },
      status: "processed",
      processed_at: Time.current
    )
    WhatsappDelivery.create!(
      whatsapp_webhook_event: event,
      message: message,
      recipient_id: "8801712345678",
      phone_number_id: "phone-1"
    )
  end

  def with_sender_result(result)
    original_deliver = WhatsappReplySender.instance_method(:deliver)
    WhatsappReplySender.define_method(:deliver) { result }
    yield
  ensure
    WhatsappReplySender.define_method(:deliver, original_deliver)
  end
end
