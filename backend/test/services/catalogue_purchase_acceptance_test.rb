require "test_helper"

class CataloguePurchaseAcceptanceTest < ActiveSupport::TestCase
  setup do
    @business = Business.create!(name: "Modz Test", slug: "purchase-acceptance", category: "electronics")
    @charger = @business.products.create!(name: "Anker Nano 45W Type-C Fast Charger", category: "charger", price: 1849, stock_quantity: 10)
    @buds = @business.products.create!(name: "Hoco EQ34 Plus", category: "earbuds", price: 729, stock_quantity: 10)
    @customer = "acceptance"
  end

  test "production Banglish purchase references select the offered charger instead of discovery" do
    [ "etai nibo", "ai product tai nite chai", "charger ta", "ei product ta-i nite chai", "I will take this one" ].each_with_index do |text, index|
      @customer = "acceptance-#{index}"
      record("hi")
      record("charger ase?")
      result = record(text)
      assert_equal @charger.id, result.pending_order.reload.product_id, text
      assert_predicate result.pending_order, :collecting_quantity?, text
      assert_nil result.pending_order.quantity, text
      assert_includes result.bot_reply.content, "1849", text
      assert_equal "select_product", result.interpretation.intent, text
    end
  end

  test "exact production retry sequence never loses the charger or confirms an order" do
    record("hi")
    record("charger ase?")
    record("etai nibo")
    record("ai product tai nite chai")
    record("charger ta")
    result = record("g")
    assert_equal @charger.id, result.pending_order.reload.product_id
    assert_nil result.pending_order.quantity
    refute_predicate result.pending_order, :confirmed?
    refute_predicate result.conversation.reload, :handed_over?
    assert_empty @business.orders
  end

  test "g and ji accept a single product only after a purchase question" do
    %w[g ji].each_with_index do |text, index|
      @customer = "ack-#{index}"
      result = record("charger ase?")
      prompt = result.conversation.messages.create!(sender_type: :bot, content: "Apni ki eta-i nite chan?")
      ConversationQuestionState.new(result.conversation).record!(message: prompt, order: result.pending_order,
        contract: { "kind" => "product_acceptance", "pending_order_id" => result.pending_order.id,
          "offered_product_ids" => [ @charger.id ] })
      result = record(text)
      assert_equal @charger.id, result.pending_order.reload.product_id
      assert_equal "select_product", result.interpretation.intent
      assert_predicate result.pending_order, :collecting_quantity?
      assert_nil result.pending_order.quantity
      assert_empty @business.orders
    end
  end

  test "yes to a device question cannot select a product" do
    result = record("charger ase?")
    result.conversation.messages.create!(sender_type: :bot, content: "Kon device-er sathe use korben?")
    result = record("g")
    assert_nil result.pending_order.reload.product_id
    assert_empty @business.orders
  end

  test "quantity questions and corrections cannot accept a product offer" do
    [ "Does it include 2 pieces?", "not 2 ta", "another 2 ta" ].each_with_index do |text, index|
      @customer = "quantity-question-#{index}"
      record("Samsung A54 er jonno charger lagbe")
      result = record(text)
      assert_nil result.pending_order.reload.product_id, text
      assert_nil result.pending_order.quantity, text
    end
  end

  test "ambiguous purchase acceptance preserves the offer list and asks which product" do
    result = record("hi")
    offered = result.conversation.reload.conversation_state["last_offered_options"]
    result = record("etai nibo")
    assert_equal :offered_reference_clarification, result.outcome
    assert_nil result.pending_order.reload.product_id
    assert_equal offered, result.conversation.reload.conversation_state["last_offered_options"]
  end

  test "category selection chooses only the matching category among offered products" do
    record("hi")
    result = record("charger ta")
    assert_equal @charger.id, result.pending_order.reload.product_id
    assert_nil result.pending_order.quantity
  end

  test "category choice cannot pick arbitrarily between two offered chargers" do
    @business.products.create!(name: "Other USB-C Charger", category: "charger", price: 999, stock_quantity: 3)
    record("charger ase?")
    result = record("charger ta")
    assert_equal :offered_reference_clarification, result.outcome
    assert_nil result.pending_order.reload.product_id
  end

  test "factual and negative references cannot become purchases" do
    [ "etai nibo na", "ei product er dam koto?", "charger ase?" ].each_with_index do |text, index|
      @customer = "not-buying-#{index}"
      record("charger ase?")
      result = record(text)
      assert_nil result.pending_order.reload.product_id, text
      assert_nil result.pending_order.quantity, text
    end
  end

  test "stale and cross-business offer ids cannot select products" do
    other = Business.create!(name: "Other", slug: "purchase-other")
    hidden = other.products.create!(name: "Private charger", price: 1, stock_quantity: 10)
    result = record("charger ase?")
    @charger.update!(stock_quantity: 0)
    state = result.conversation.reload.conversation_state
    state["last_offered_options"]["options"] << { "id" => hidden.id }
    result.conversation.update!(conversation_state: state)
    result = record("etai nibo")
    assert_nil result.pending_order.reload.product_id
  end

  test "g and ji never confirm a complete checkout" do
    result = record("charger ase?")
    order = result.pending_order
    order.update!(product: @charger, quantity: 1, customer_name: "SQA Test", phone: "01700000000", address: "SQA Test Dhaka", status: :awaiting_confirmation)
    %w[g ji].each do |text|
      result = record(text)
      refute_predicate result.pending_order.reload, :confirmed?
      assert_empty @business.orders
    end
  end

  test "acceptance routing does not depend on a mistaken classifier recommendation" do
    %w[product_recommendation list_products select_product confirm_order].each_with_index do |intent, index|
      @customer = "wrong-intent-#{index}"
      result = record("charger ase?")
      message = result.conversation.messages.create!(sender_type: :customer, content: "charger ta")
      interpretation = AiIntentClassifier::Result.new(intent: intent, confidence: 0.99,
        entities: {}.with_indifferent_access, language: "banglish", sentiment: "neutral",
        secondary_intents: [], needs_clarification: false, possible_intents: [])
      processor = ConversationMessageProcessor.new(message: message, pending_order: result.pending_order, interpretation: interpretation)
      processor.process
      assert_equal :product_selected, processor.outcome, intent
      assert_equal @charger.id, result.pending_order.reload.product_id, intent
      assert_nil result.pending_order.quantity, intent
    end
  end

  test "acceptance keeps the variant question and does not auto choose an option" do
    @charger.product_variants.create!(name: "White", size: "White", price: 1849, stock_quantity: 3)
    @charger.product_variants.create!(name: "Black", size: "Black", price: 1849, stock_quantity: 3)
    record("charger ase?")
    result = record("etai nibo")
    assert_equal @charger.id, result.pending_order.reload.product_id
    assert_predicate result.pending_order, :collecting_variant?
    assert_nil result.pending_order.product_variant_id
    assert_nil result.pending_order.quantity
  end

  test "accepting the same selected option twice preserves its variant" do
    variant = @charger.product_variants.create!(name: "Black", size: "Black", price: 1849, stock_quantity: 3)
    result = record("charger ase?")
    result.pending_order.update!(product: @charger, product_variant: variant, status: :collecting_quantity)
    result = record("etai nibo")
    assert_equal variant.id, result.pending_order.reload.product_variant_id
    assert_predicate result.pending_order, :collecting_quantity?
    assert_nil result.pending_order.quantity
  end

  test "purchase acceptance does not rewrite terminal orders or saved cart lines" do
    result = record("charger ase?")
    order = result.pending_order
    %i[confirmed submitted_to_woocommerce cancelled].each do |status|
      order.update!(product: @charger, quantity: 1, status: status)
      message = result.conversation.messages.create!(sender_type: :customer, content: "etai nibo")
      assert_nil CataloguePurchaseAcceptance.new(message: message, pending_order: order).call
      assert_equal status.to_s, order.reload.status
      assert_equal 1, order.quantity
    end
    order.update!(product: nil, quantity: nil, status: :collecting_product)
    order.pending_order_items.create!(product: @buds, quantity: 2)
    message = result.conversation.messages.create!(sender_type: :customer, content: "etai nibo")
    assert_nil CataloguePurchaseAcceptance.new(message: message, pending_order: order).call
    assert_equal [ @buds.id ], order.reload.pending_order_items.pluck(:product_id)
  end

  private

  def record(text)
    CustomerMessageRecorder.new(business: @business, channel: "facebook", external_customer_id: @customer, content: text).record
  end
end
