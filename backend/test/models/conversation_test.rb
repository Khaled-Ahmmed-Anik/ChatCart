require "test_helper"

class ConversationTest < ActiveSupport::TestCase
  test "validates required external customer and channel" do
    conversation = Conversation.new

    assert_not conversation.valid?
    assert_includes conversation.errors[:external_customer_id], "can't be blank"
    assert_includes conversation.errors[:channel], "can't be blank"
  end

  test "defaults to active status" do
    conversation = Conversation.create!(channel: "facebook", external_customer_id: "customer-1")

    assert_predicate conversation, :active?
  end

  test "requires unique customer per channel" do
    Conversation.create!(channel: "facebook", external_customer_id: "customer-1")

    duplicate = Conversation.new(channel: "facebook", external_customer_id: "customer-1")

    assert_raises(ActiveRecord::RecordNotUnique) do
      duplicate.save!(validate: false)
    end
  end

  test "allows same external customer on different channels" do
    Conversation.create!(channel: "facebook", external_customer_id: "customer-1")
    conversation = Conversation.new(channel: "instagram", external_customer_id: "customer-1")

    assert conversation.valid?
  end

  test "destroys dependent messages and pending order" do
    conversation = Conversation.create!(channel: "facebook", external_customer_id: "customer-1")
    conversation.messages.create!(sender_type: :customer, content: "Hi")
    conversation.create_pending_order!

    assert_difference -> { Message.count }, -1 do
      assert_difference -> { PendingOrder.count }, -1 do
        conversation.destroy!
      end
    end
  end
end
