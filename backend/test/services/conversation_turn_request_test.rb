require "test_helper"

class ConversationTurnRequestTest < ActiveSupport::TestCase
  test "final contrast clause determines whether a purchase is declined" do
    assert ConversationTurnRequest.new("I wanted this but etai nibo na").purchase_declined?
    assert_not ConversationTurnRequest.new("etai nibo na but Hoco EQ34 Plus nibo").purchase_declined?
    assert_not ConversationTurnRequest.new("not waterproof but I will take this").purchase_declined?
  end

  test "comparison questions are informational even when they mention counts" do
    assert ConversationTurnRequest.new("duitar difference ki? battery koto khon chole?").information_only?
    assert_not ConversationTurnRequest.new("Hoco EQ34 Plus duita den").information_only?
  end
end
