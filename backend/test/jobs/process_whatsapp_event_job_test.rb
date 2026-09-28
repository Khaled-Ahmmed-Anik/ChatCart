require "test_helper"

class ProcessWhatsappEventJobTest < ActiveJob::TestCase
  test "processes an inbound WhatsApp message and queues a reply" do
    Product.create!(name: "Fresh Musk", price: 750, stock_quantity: 10)
    event = WhatsappWebhookEvent.create!(
      business: Business.default,
      event_type: "customer_text",
      external_event_id: "wamid.inbound-1",
      sender_id: "8801712345678",
      phone_number_id: "phone-number-1",
      payload: { text: { body: "I want Fresh Musk" } }
    )

    assert_difference -> { Conversation.where(channel: "whatsapp").count }, 1 do
      assert_difference -> { WhatsappDelivery.count }, 1 do
        assert_enqueued_with(job: SendWhatsappReplyJob) { ProcessWhatsappEventJob.perform_now(event) }
      end
    end

    delivery = event.reload.whatsapp_delivery
    assert_equal "processed", event.status
    assert_equal "8801712345678", delivery.recipient_id
    assert_equal "phone-number-1", delivery.phone_number_id
    assert_includes delivery.message.content, "Fresh Musk"
  end
end
