require "test_helper"

class ConversationResponsePlannerTest < ActiveSupport::TestCase
  test "answers an interruption and returns to the pending order question" do
    order = create_pending_order(status: :collecting_phone, customer_name: "Anik")
    message = order.conversation.messages.create!(sender_type: :customer, content: "delivery charge koto?")

    plan = build_planner(
      order: order,
      message: message,
      outcome: :delivery_charge_requested,
      interpretation: interpretation(intent: "delivery_charge", language: "banglish")
    ).plan

    assert plan.interrupted
    assert_includes plan.content, "To continue your order: What phone number"
    assert_equal "banglish", plan.language
    assert_equal "phone", order.conversation.reload.conversation_state["pending_question"]
  end

  test "asks a focused question when new and changed orders are both possible" do
    order = create_pending_order(status: :awaiting_confirmation)
    message = order.conversation.messages.create!(sender_type: :customer, content: "order ta change kori")

    plan = build_planner(
      order: order,
      message: message,
      outcome: :clarification_needed,
      interpretation: interpretation(
        intent: "change_confirmed_order",
        needs_clarification: true,
        possible_intents: %w[change_confirmed_order new_order]
      )
    ).plan

    assert_equal "Do you want to change your current order, or start a new order?", plan.content
  end

  test "uses a calmer tone after a negative customer message" do
    order = create_pending_order
    message = order.conversation.messages.create!(sender_type: :customer, content: "This is frustrating")

    plan = build_planner(
      order: order,
      message: message,
      outcome: :complaint,
      interpretation: interpretation(intent: "complaint", sentiment: "negative")
    ).plan

    assert_equal "calm_and_helpful", plan.tone
    assert_equal "calm_and_helpful", order.conversation.reload.conversation_state["preferred_tone"]
  end

  test "keeps the remembered language when detection confidence is weak" do
    conversation = Conversation.create!(
      channel: "facebook",
      external_customer_id: SecureRandom.uuid,
      conversation_state: { "preferred_language" => "bengali" }
    )
    order = conversation.create_pending_order!
    message = conversation.messages.create!(sender_type: :customer, content: "ok")

    plan = build_planner(
      order: order,
      message: message,
      outcome: :thanks,
      interpretation: interpretation(intent: "thanks", language: "english", confidence: 0.6)
    ).plan

    assert_equal "bengali", plan.language
  end

  private

  def build_planner(order:, message:, outcome:, interpretation:)
    ConversationResponsePlanner.new(
      conversation: order.conversation,
      pending_order: order,
      customer_message: message,
      outcome: outcome,
      interpretation: interpretation
    )
  end

  def create_pending_order(attributes = {})
    conversation = Conversation.create!(channel: "facebook", external_customer_id: SecureRandom.uuid)
    conversation.create_pending_order!(attributes)
  end

  def interpretation(
    intent:, language: "english", sentiment: "neutral", confidence: 0.95,
    needs_clarification: false, possible_intents: []
  )
    AiIntentClassifier::Result.new(
      intent: intent,
      confidence: confidence,
      entities: {}.with_indifferent_access,
      language: language,
      sentiment: sentiment,
      needs_clarification: needs_clarification,
      possible_intents: possible_intents
    )
  end
end
