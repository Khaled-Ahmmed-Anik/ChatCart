require "test_helper"

class MessageTest < ActiveSupport::TestCase
  test "belongs to a conversation" do
    message = Message.new(sender_type: :customer, content: "Hi")

    assert_not message.valid?
    assert_includes message.errors[:conversation], "must exist"
  end

  test "validates content" do
    message = Message.new(conversation: create_conversation, sender_type: :customer, content: nil)

    assert_not message.valid?
    assert_includes message.errors[:content], "can't be blank"
  end

  test "stores sender type enum" do
    message = Message.create!(conversation: create_conversation, sender_type: :bot, content: "Hello")

    assert_predicate message, :bot?
  end

  test "defaults metadata to an empty hash" do
    message = Message.create!(conversation: create_conversation, sender_type: :customer, content: "Hi")

    assert_equal({}, message.metadata)
  end

  private

  def create_conversation
    Conversation.create!(channel: "facebook", external_customer_id: SecureRandom.uuid)
  end
end
