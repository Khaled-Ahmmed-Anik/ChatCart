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
    assert_equal "Nice choice! Fresh Musk is ৳750 per bottle. How many would you like?", delivery.message.content
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

  test "combines rapid customer messages into one conversational turn and one reply" do
    Product.create!(
      name: "The Office", price: 350, stock_quantity: 10,
      short_description: "A fresh, clean fragrance for office use.",
      tags: "fresh clean office"
    )
    first = create_webhook_event(text: "single", message_id: "mid-batch-1")
    second = create_webhook_event(text: "fresh for office under 500", message_id: "mid-batch-2")

    assert_difference -> { Message.customer.count }, 1 do
      assert_difference -> { Message.bot.count }, 1 do
        assert_difference -> { MessengerDelivery.count }, 1 do
          ProcessMessengerEventJob.perform_now(first)
        end
      end
    end

    conversation = Conversation.find_by!(external_customer_id: first.sender_id)
    customer_message = conversation.messages.customer.last
    assert_equal "single\nfresh for office under 500", customer_message.content
    assert_equal 2, customer_message.metadata["batched_message_count"]
    assert_equal %w[mid-batch-1 mid-batch-2], customer_message.metadata["batched_message_ids"]
    assert_equal "processed", first.reload.status
    assert_equal "processed", second.reload.status
    assert_nil first.messenger_delivery
    assert second.messenger_delivery.present?

    assert_no_difference [ -> { Message.count }, -> { MessengerDelivery.count } ] do
      ProcessMessengerEventJob.perform_now(second)
    end
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
