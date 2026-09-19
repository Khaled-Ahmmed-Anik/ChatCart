require "test_helper"

class ConversationIntentDetectorTest < ActiveSupport::TestCase
  test "recognizes English and Banglish repeat-order requests" do
    [
      "new order?",
      "Can I place another order?",
      "noton order kora jabe?",
      "notun order korte chai",
      "abar order korbo",
      "re-order korbo",
      "order korbo"
    ].each do |content|
      assert ConversationIntentDetector.new(content).new_order?, content
    end
  end

  test "recognizes English and Banglish order-detail requests" do
    [
      "show my order",
      "my order details",
      "amar order details ta ki silo?",
      "amar order ki chilo?",
      "order ta ki silo?"
    ].each do |content|
      assert ConversationIntentDetector.new(content).order_details?, content
    end
  end

  test "does not confuse an update request with an order-detail request" do
    assert_not ConversationIntentDetector.new("change my order").order_details?
  end
end
