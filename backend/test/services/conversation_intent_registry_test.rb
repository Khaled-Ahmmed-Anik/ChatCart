require "test_helper"

class ConversationIntentRegistryTest < ActiveSupport::TestCase
  test "defines a bounded registry of fifty seller and buyer topics" do
    assert_equal 50, ConversationIntentRegistry::INTENTS.size
    assert_equal ConversationIntentRegistry::INTENTS.uniq, ConversationIntentRegistry::INTENTS
    assert ConversationIntentRegistry.valid?("repeat_order")
    assert ConversationIntentRegistry.valid?("refund_request")
    assert_not ConversationIntentRegistry.valid?("invent_discount")
  end
end
