require "test_helper"
require_relative "../support/conversation_journey_assertions"

class ConversationQuestionStateTest < ActiveSupport::TestCase
  include ConversationJourneyAssertions

  setup do
    @business = Business.create!(name: "Question Shop", slug: "question-state", category: "electronics")
    @product = @business.products.create!(name: "Anker Charger", category: "charger", price: 1849, stock_quantity: 10)
  end

  test "typed purchase question accepts acknowledgements despite rewording" do
    result = assert_conversation_journey(business: @business, customer: "typed", steps: [
      { say: "Samsung A54 er jonno charger lagbe", order: { product_id: nil } }
    ]).last
    question = result.conversation.reload.conversation_state.fetch("active_question")
    assert_equal "product_acceptance", question["kind"]
    result.bot_reply.update!(content: "Shall we go ahead?")
    result = assert_conversation_journey(business: @business, customer: "typed", steps: [
      { say: "ji", order: { product_id: @product.id, quantity: nil, status: "collecting_quantity" } }
    ]).last
    question = result.conversation.reload.conversation_state.fetch("active_question")
    assert_equal "quantity", question["kind"]
    assert_equal "positive_integer", question["expected_answer"]
    assert_equal "answered", result.conversation.conversation_state["question_history"].last["status"]
  end

  test "rewriter cannot turn a device question into purchase acceptance" do
    result = assert_conversation_journey(business: @business, customer: "device", steps: [ { say: "charger ase?" } ]).last
    assert_equal "discovery_use", result.conversation.conversation_state.dig("active_question", "kind")
    result.bot_reply.update!(content: "Would you like to order this product?")
    assert_conversation_journey(business: @business, customer: "device", steps: [ { say: "g", order: { product_id: nil } } ])
  end

  test "question identifiers bind acknowledgement to current order and offer" do
    result = assert_conversation_journey(business: @business, customer: "stale", steps: [ { say: "Samsung A54 er jonno charger lagbe" } ]).last
    old_question = result.conversation.conversation_state["active_question"]
    new_order = result.conversation.create_pending_order!
    message = result.conversation.messages.create!(sender_type: :customer, content: "ji")
    refute ConversationQuestionState.new(result.conversation).purchase_offer?(message: message, order: new_order)
    assert_equal old_question, result.conversation.reload.conversation_state["active_question"]
  end

  test "cancelled orders close the active question and bound history" do
    result = assert_conversation_journey(business: @business, steps: [
      { say: "charger ase?" }, { say: "etai nibo" }, { say: "cancel", order: { status: "cancelled" } }
    ]).last
    assert_equal "closed", result.conversation.conversation_state.dig("active_question", "status")
    assert_operator result.conversation.conversation_state["question_history"].size, :<=, Constants::Conversation::QUESTION_HISTORY_LIMIT
    refute result.conversation.conversation_state["active_question"].key?("kind")
  end
end
