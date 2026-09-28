require "test_helper"

class ConversationIntentRegistryTest < ActiveSupport::TestCase
  test "defines a bounded registry of seller and buyer topics" do
    assert_equal 59, ConversationIntentRegistry.intents.size
    assert_equal ConversationIntentRegistry.intents.uniq, ConversationIntentRegistry.intents
    assert ConversationIntentRegistry.valid?("repeat_order")
    assert ConversationIntentRegistry.valid?("refund_request")
    assert ConversationIntentRegistry.valid?("reject_recommendations")
    assert ConversationIntentRegistry.valid?("shortlist_add")
    assert ConversationIntentRegistry.valid?("go_back")
    assert_not ConversationIntentRegistry.valid?("invent_discount")
  end
end
