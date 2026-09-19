require "test_helper"

class MessengerEventClassifierTest < ActiveSupport::TestCase
  test "classifies customer text" do
    assert_equal :customer_text, classify(sender: { id: "fb-user" }, message: { text: "Hello" })
  end

  test "classifies page message echoes before customer text" do
    assert_equal :message_echo, classify(
      sender: { id: "page-1" },
      message: { is_echo: true, text: "Our reply" }
    )
  end

  test "classifies delivery receipts" do
    assert_equal :delivery, classify(delivery: { mids: [ "message-1" ] })
  end

  test "classifies read receipts" do
    assert_equal :read, classify(read: { watermark: 1_780_000_000_000 })
  end

  test "classifies postbacks" do
    assert_equal :postback, classify(postback: { payload: "CONFIRM_ORDER" })
  end

  test "classifies attachment-only messages" do
    assert_equal :attachment, classify(
      sender: { id: "fb-user" },
      message: { attachments: [ { type: "image" } ] }
    )
  end

  test "classifies malformed messages" do
    assert_equal :malformed_message, classify(sender: {}, message: {})
  end

  test "classifies unknown events" do
    assert_equal :unknown, classify(sender: { id: "fb-user" }, reaction: { action: "react" })
  end

  private

  def classify(event)
    MessengerEventClassifier.new(event.with_indifferent_access).type
  end
end
