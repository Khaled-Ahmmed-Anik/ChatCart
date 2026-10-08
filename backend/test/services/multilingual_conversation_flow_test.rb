require "test_helper"

class MultilingualConversationFlowTest < ActiveSupport::TestCase
  setup do
    @business = Business.create!(name: "Everyday Shop", slug: "multilingual-everyday", category: "clothing")
    @business.create_business_policy!(delivery_charges: "Dhaka: 80 taka")
    @shirt = @business.products.create!(name: "Cotton Shirt", price: 600, stock_quantity: 20)
    @bag = @business.products.create!(name: "Canvas Bag", price: 450, stock_quantity: 10)
    @conversation = @business.conversations.create!(channel: "facebook", external_customer_id: SecureRandom.uuid)
    @order = @conversation.create_pending_order!(status: :collecting_product)
  end

  test "English and Banglish multi-intent orders answer delivery before checkout" do
    [ "Cotton Shirt two pieces den, delivery charge koto?",
      "Cotton Shirt 2 pieces please, how much is delivery?" ].each do |text|
      processor, message = process_turn(text)
      assert_equal :multiple_details_collected, processor.outcome
      assert_equal [ @shirt.id, 2, "collecting_name" ], @order.reload.values_at(:product_id, :quantity, :status)
      plan = ConversationResponsePlanner.new(
        conversation: @conversation, pending_order: @order, customer_message: message,
        outcome: processor.outcome, secondary_outcomes: processor.secondary_outcomes
      ).plan
      assert_operator plan.content.index("Dhaka: 80"), :<, plan.content.index("name"), plan.content
    end
  end

  test "budget and delivery numbers never become quantities in action plans" do
    [ "Cotton Shirt under 1000 taka chai", "Cotton Shirt delivery in two days please",
      "Cotton Shirt 600 taka price?", "Cotton Shirt 2 pieces nibo na",
      "I don't want Cotton Shirt 2 pieces" ].each do |text|
      message = @conversation.messages.create!(sender_type: :customer, content: text)
      plan = ConversationActionPlanner.new(message: message, business: @business).call
      assert_not plan.actionable?, text
    end
  end

  test "previous product reference works after a topic switch in both languages" do
    @conversation.update!(conversation_state: {
      "turn_manager" => { "reference_history" => [ { "product_id" => @shirt.id }, { "product_id" => @bag.id } ] }
    })
    [ "ager ta den", "the previous one please" ].each do |text|
      @order.update!(product: @bag, status: :collecting_product)
      processor, = process_turn(text)
      assert_equal :product_selected, processor.outcome
      assert_equal @shirt.id, @order.reload.product_id
    end
  end

  test "unsupported model product and quantity cannot change checkout" do
    @order.update!(product: @shirt, status: :collecting_quantity)
    interpretation = AiIntentClassifier::Result.new(
      intent: "select_quantity", confidence: 0.99, entities: { quantity: 7 }.with_indifferent_access,
      language: "english", sentiment: "neutral", needs_clarification: false, possible_intents: []
    )
    processor, = process_turn("how much is delivery?", interpretation: interpretation)
    assert_equal :delivery_charge_requested, processor.outcome
    assert_nil @order.reload.quantity
    assert_predicate @order, :collecting_quantity?
  end

  test "normalization improves held-out Banglish price spelling without Gemini" do
    %w[daam damm].each do |word|
      message = @conversation.messages.create!(sender_type: :customer, content: "#{word} kotho")
      result = CompactIntentClassifier.new(message: message, pending_order: @order).classify
      assert_equal "product_price", result.interpretation&.intent
    end
  end

  test "a clothing checkout keeps its selection through side questions and a quantity correction" do
    @shirt.product_variants.create!(name: "Large", size: "L", price: 650, stock_quantity: 10)
    selected = @shirt.product_variants.create!(name: "Medium", size: "M", price: 600, stock_quantity: 10)
    processor, = process_turn("Cotton Shirt Medium two pieces den")
    assert_equal :multiple_details_collected, processor.outcome
    assert_equal selected.id, @order.reload.product_variant_id

    process_turn("delivery charge koto?")
    assert_equal [ @shirt.id, selected.id, 2 ], @order.reload.values_at(:product_id, :product_variant_id, :quantity)
    assert_predicate @order, :collecting_name?

    processor, = process_turn("actually make it one")
    assert_equal :order_updated, processor.outcome
    assert_equal 1, @order.reload.quantity
    assert_equal selected.id, @order.product_variant_id
  end

  test "ambiguous model decisions cannot apply a combined purchase" do
    interpretation = AiIntentClassifier::Result.new(
      intent: "select_product", confidence: 0.4, entities: { product_name: "Cotton Shirt", quantity: 2 }.with_indifferent_access,
      language: "english", sentiment: "neutral", needs_clarification: true, possible_intents: %w[select_product product_price]
    )
    processor, = process_turn("Cotton Shirt two pieces?", interpretation: interpretation)
    assert_equal :clarification_needed, processor.outcome
    assert_nil @order.reload.product_id
    assert_nil @order.quantity
  end

  test "a clothing size letter must not match a letter inside another word" do
    @shirt.product_variants.create!(name: "Large", size: "L", price: 650, stock_quantity: 10)
    message = @conversation.messages.create!(sender_type: :customer, content: "Cotton Shirt two pieces delivery charge koto")
    plan = ConversationActionPlanner.new(message: message, business: @business).call
    assert_nil plan.variant
  end

  test "a similarly named product from another business cannot enter an action plan" do
    other = Business.create!(name: "Other Shop", slug: "multilingual-other")
    other.products.create!(name: "Silk Shirt", price: 900, stock_quantity: 10)
    message = @conversation.messages.create!(sender_type: :customer, content: "Silk Shirt 2 pieces den")
    plan = ConversationActionPlanner.new(message: message, business: @business).call
    assert_nil plan.product
    assert_not plan.actionable?
  end

  private

  def process_turn(content, interpretation: nil)
    message = @conversation.messages.create!(sender_type: :customer, content: content)
    processor = ConversationMessageProcessor.new(message: message, pending_order: @order, interpretation: interpretation)
    processor.process
    [ processor, message ]
  end
end
