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

  test "answers multiple requests and returns to the active order step" do
    order = create_pending_order(status: :collecting_quantity)
    product = order.conversation.business.products.create!(name: "Fresh Musk", price: 750, stock_quantity: 5)
    order.update!(product: product)
    order.conversation.business.create_business_policy!(delivery_charges: "Dhaka delivery is ৳80.")
    message = order.conversation.messages.create!(sender_type: :customer, content: "price and delivery charge?")

    plan = ConversationResponsePlanner.new(
      conversation: order.conversation,
      pending_order: order,
      customer_message: message,
      outcome: :price_inquiry,
      secondary_outcomes: [ :delivery_charge_requested ],
      interpretation: interpretation(intent: "product_price")
    ).plan

    assert_includes plan.content, "Fresh Musk is ৳750"
    assert_includes plan.content, "Dhaka delivery is ৳80."
    assert_includes plan.content, "To continue your order"
  end

  test "keeps product discovery focused instead of combining unrelated secondary prompts" do
    order = create_pending_order(status: :collecting_product)
    order.conversation.update!(conversation_state: { "shopping_preferences" => { "format" => "single" } })
    message = order.conversation.messages.create!(sender_type: :customer, content: "ekta")

    plan = ConversationResponsePlanner.new(
      conversation: order.conversation,
      pending_order: order,
      customer_message: message,
      outcome: :product_recommendation_requested,
      secondary_outcomes: [ :help, :product_variants_requested ],
      interpretation: interpretation(intent: "product_recommendation")
    ).plan

    assert_includes plan.content, "What style do you prefer"
    assert_not_includes plan.content, "new order"
    assert_not_includes plan.content, "size"
  end

  test "remembers and naturally mirrors the customer's form of address" do
    order = create_pending_order
    message = order.conversation.messages.create!(sender_type: :customer, content: "Bhai, hello")

    plan = build_planner(
      order: order,
      message: message,
      outcome: :greeting,
      interpretation: interpretation(intent: "greeting", language: "banglish")
    ).plan

    assert_equal "bhai", plan.address_preference
    assert_includes plan.content, "Assalamu alaikum, bhai!"
    assert_equal "bhai", order.conversation.reload.conversation_state["address_preference"]

    follow_up = order.conversation.messages.create!(sender_type: :customer, content: "thanks")
    next_plan = build_planner(
      order: order,
      message: follow_up,
      outcome: :thanks,
      interpretation: interpretation(intent: "thanks", language: "banglish")
    ).plan
    assert_includes next_plan.content, "welcome, bhai"
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
