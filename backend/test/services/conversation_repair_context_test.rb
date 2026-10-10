require "test_helper"

class ConversationRepairContextTest < ActiveSupport::TestCase
  setup do
    @conversation = Conversation.create!(channel: "facebook", external_customer_id: SecureRandom.uuid)
    @order = @conversation.create_pending_order!(status: :collecting_product)
  end

  test "second misunderstanding uses the recent delivery context instead of a generic menu" do
    @conversation.messages.create!(sender_type: :customer, content: "What about shipping?", metadata: {
      "conversation_intelligence" => { "outcome" => "product_not_found" }
    })
    message = @conversation.messages.create!(sender_type: :customer, content: "that is what I meant")
    reply = BotReplyGenerator.new(pending_order: @order, customer_message: message, outcome: :product_not_found).content
    assert_includes reply, "delivery estimate"
    assert_not_includes reply, "budget"
    assert_predicate @order.reload, :collecting_product?
  end

  test "successful answer resets the repeated repair question" do
    @conversation.messages.create!(sender_type: :customer, content: "shipping", metadata: {
      "conversation_intelligence" => { "outcome" => "delivery_charge_requested" }
    })
    message = @conversation.messages.create!(sender_type: :customer, content: "what about that?")
    assert_not ConversationRepairContext.new(conversation: @conversation, message: message).repeated?
  end

  test "support follow-up preserves the draft and stays in support context" do
    @conversation.messages.create!(sender_type: :customer, content: "Login failed", metadata: {
      "conversation_intelligence" => { "outcome" => "unsupported_support_requested" }
    })
    message = @conversation.messages.create!(sender_type: :customer, content: "still not working")
    processor = ConversationMessageProcessor.new(message: message, pending_order: @order)
    processor.process
    assert_equal :unsupported_support_requested, processor.outcome
    assert_predicate @order.reload, :collecting_product?
  end

  test "handover follows the stored language in all supported forms" do
    { "english" => "Please wait", "banglish" => "Ektu opekkha", "bangla" => "অনুগ্রহ" }.each do |language, expected|
      @conversation.update!(conversation_state: { "preferred_language" => language })
      reply = BotReplyGenerator.new(pending_order: @order, outcome: :human_handover_started).content
      assert_includes reply, expected
    end
  end

  test "an unrelated new product request does not inherit a support failure" do
    @conversation.messages.create!(sender_type: :customer, content: "Login failed", metadata: {
      "conversation_intelligence" => { "outcome" => "unsupported_support_requested" }
    })
    message = @conversation.messages.create!(sender_type: :customer, content: "I still want a shirt")
    assert_not ConversationRepairContext.new(conversation: @conversation, message: message).support_follow_up?
  end
end
