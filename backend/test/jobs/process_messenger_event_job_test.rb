require "test_helper"

class ProcessMessengerEventJobTest < ActiveJob::TestCase
  test "processes an inbound message and enqueues its outbound reply" do
    Product.create!(name: "Fresh Musk", price: 750, stock_quantity: 10)
    event = create_webhook_event(text: "I want Fresh Musk")

    assert_difference -> { Conversation.count }, 1 do
      assert_difference -> { Message.count }, 2 do
        assert_difference -> { MessengerDelivery.count }, 1 do
          assert_enqueued_with(job: SendMessengerReplyJob) do
            ProcessMessengerEventJob.perform_now(event)
          end
        end
      end
    end

    event.reload
    delivery = event.messenger_delivery
    assert_equal "processed", event.status
    assert event.processed_at.present?
    assert_equal "pending", delivery.status
    assert_equal event.sender_id, delivery.recipient_id
    assert_equal "Great choice. How many bottles of Fresh Musk would you like?", delivery.message.content
  end

  test "does not process an already processed event twice" do
    event = create_webhook_event(text: "Hello")
    ProcessMessengerEventJob.perform_now(event)

    assert_no_difference [ -> { Message.count }, -> { MessengerDelivery.count } ] do
      ProcessMessengerEventJob.perform_now(event.reload)
    end
  end

  test "preserves the existing ordering and confirmation flow" do
    product = Product.create!(name: "Fresh Musk", price: 750, stock_quantity: 10)

    %w[I\ want\ Fresh\ Musk 2 Khaled +8801725126467 Dhaka confirm].each_with_index do |text, index|
      ProcessMessengerEventJob.perform_now(create_webhook_event(text: text, message_id: "mid-#{index}"))
    end

    order = Conversation.find_by!(external_customer_id: "fb-user-123").pending_order
    assert_equal product, order.product
    assert_equal 2, order.quantity
    assert_equal "Khaled", order.customer_name
    assert_equal "+8801725126467", order.phone
    assert_equal "Dhaka", order.address
    assert_predicate order, :confirmed?
  end

  private

  def create_webhook_event(text:, message_id: "mid-123")
    MessengerWebhookEvent.create!(
      event_type: "customer_text",
      external_event_id: message_id,
      sender_id: "fb-user-123",
      payload: {
        sender: { id: "fb-user-123" },
        message: { mid: message_id, text: text }
      }
    )
  end
end
