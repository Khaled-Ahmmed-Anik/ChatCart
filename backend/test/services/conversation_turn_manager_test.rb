require "test_helper"

class ConversationTurnManagerTest < ActiveSupport::TestCase
  test "preserves the active checkout goal while recording an answered side question" do
    conversation, order, product, variant = build_order(status: :collecting_phone)
    conversation.update!(conversation_state: {
      "context_switch_count" => 1,
      "turn_manager" => { "active_goal" => "checkout" }
    })
    message = conversation.messages.create!(sender_type: :customer, content: "delivery charge koto?")

    turn = manager(conversation).record_turn!(
      message: message, pending_order: order, outcome: :delivery_charge_requested,
      interpretation: interpretation("delivery_charge"), secondary_outcomes: [], interrupted: true
    )

    assert_equal "checkout", turn["active_goal"]
    assert_equal "collecting_phone", turn["order_step"]
    assert_equal "phone", turn.dig("pending_question", "field")
    assert_equal product.id, turn.dig("paused_task", "product_id")
    assert_equal variant.id, turn.dig("reference", "variant_id")
    assert_equal "delivery_charge_requested", turn.dig("side_questions", -1, "outcome")
    assert turn.dig("side_questions", -1, "answered")
  end

  test "clears the paused task after the customer advances checkout" do
    conversation, order = build_order(status: :collecting_phone)
    conversation.update!(conversation_state: {
      "turn_manager" => {
        "active_goal" => "checkout",
        "paused_task" => { "goal" => "checkout", "order_step" => "collecting_phone" }
      }
    })
    order.update!(phone: "01712345678", status: :collecting_address)
    message = conversation.messages.create!(sender_type: :customer, content: "01712345678")

    turn = manager(conversation).record_turn!(
      message: message, pending_order: order, outcome: :phone_collected,
      interpretation: nil, secondary_outcomes: [], interrupted: false
    )

    assert_nil turn["paused_task"]
    assert_equal "address", turn.dig("pending_question", "field")
    assert_equal "checkout", turn["active_goal"]
  end

  test "records unresolved ambiguity without storing customer message content" do
    conversation, order = build_order(status: :collecting_product, with_product: false)
    message = conversation.messages.create!(sender_type: :customer, content: "oi ta den secret words")
    intent = interpretation("select_product", needs_clarification: true,
      possible_intents: %w[select_product product_details])

    turn = manager(conversation).record_turn!(
      message: message, pending_order: order, outcome: :clarification_needed,
      interpretation: intent, secondary_outcomes: [], interrupted: false
    )

    assert_equal "intent", turn.dig("unresolved", "kind")
    assert_equal %w[select_product product_details], turn.dig("unresolved", "possible_intents")
    assert_not_includes turn.to_json, "secret words"
  end

  test "keeps bounded product reference history" do
    conversation, order, = build_order(status: :collecting_quantity)
    7.times do |index|
      product = conversation.business.products.create!(
        name: "Reference #{index}", price: 500 + index, stock_quantity: 5
      )
      order.update!(product: product)
      message = conversation.messages.create!(sender_type: :customer, content: "next")
      manager(conversation).record_turn!(
        message: message, pending_order: order, outcome: :product_selected,
        interpretation: nil, secondary_outcomes: [], interrupted: false
      )
    end

    history = conversation.reload.conversation_state.dig("turn_manager", "reference_history")
    assert_equal 5, history.size
    assert_equal "Reference 2", history.first["product_name"]
    assert_equal "Reference 6", history.last["product_name"]
  end

  private

  def manager(conversation)
    ConversationTurnManager.new(conversation)
  end

  def build_order(status:, with_product: true)
    conversation = Conversation.create!(channel: "facebook", external_customer_id: SecureRandom.uuid)
    return [ conversation, conversation.create_pending_order!(status: status) ] unless with_product

    product = conversation.business.products.create!(name: SecureRandom.hex(5), price: 750, stock_quantity: 0)
    variant = product.product_variants.create!(name: "30 ML", size: "30 ML", price: 850, stock_quantity: 10)
    order = conversation.create_pending_order!(product: product, product_variant: variant, quantity: 1, status: status)
    [ conversation, order, product, variant ]
  end

  def interpretation(intent, needs_clarification: false, possible_intents: [])
    AiIntentClassifier::Result.new(
      intent: intent, secondary_intents: [], confidence: 0.95, entities: {}.with_indifferent_access,
      language: "banglish", sentiment: "neutral", needs_clarification: needs_clarification,
      possible_intents: possible_intents
    )
  end
end
