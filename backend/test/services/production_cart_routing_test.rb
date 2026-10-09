require "test_helper"

class ProductionCartRoutingTest < ActiveSupport::TestCase
  setup do
    @business = Business.create!(name: "Routing Shop", slug: "routing-shop", category: "perfume")
    @office = @business.products.create!(name: "The Office", price: 350, stock_quantity: 20)
    @party = @business.products.create!(name: "The Party", price: 390, stock_quantity: 20)
    @office.product_variants.create!(name: "10 ML", size: "10 ML", price: 350, stock_quantity: 20)
    @office.product_variants.create!(name: "15 ML", size: "15 ML", price: 480, stock_quantity: 20)
    @party.product_variants.create!(name: "15 ML", size: "15 ML", price: 550, stock_quantity: 20)
    @customer = SecureRandom.uuid
  end

  test "generic Banglish additions preserve the draft and collect the next product" do
    draft = record("The Office 15 ML 5 pieces den").pending_order
    draft.update!(customer_name: "Test Customer", phone: "01700000000", address: "Test address", status: :awaiting_confirmation)
    [ "ai order a r o product add korte cai", "ager order a 2 ta product add korbo" ].each do |text|
      result = record(text)
      assert_equal :cart_needs_details, result.outcome
      assert_equal 2400.to_d, draft.reload.total_price
      assert_equal "Test Customer", draft.customer_name
    end
    result = record("The Party 15 ML 2 pieces")
    assert_equal :cart_updated, result.outcome
    assert_equal 3500.to_d, result.pending_order.total_price
    assert_equal 2, result.pending_order.line_items.size
  end

  test "quantity-first shorthand list replaces draft items without clearing customer details" do
    draft = record("The Office 15 ML 5 pieces den").pending_order
    draft.update!(customer_name: "Test Customer", phone: "01700000000", address: "Test address", status: :awaiting_confirmation)
    result = record("3 office 10 ml + 2 party 15 ml")
    assert_equal :cart_updated, result.outcome
    assert_equal 2150.to_d, result.pending_order.total_price
    assert_equal "Test Customer", result.pending_order.customer_name
    assert_equal [ 2, 3 ], result.pending_order.line_items.map(&:quantity).sort
    record("confirm")
    assert_equal 2, draft.reload.order.order_items.count
  end

  test "short product choice and numeric size resolve against the question asked" do
    record("suggest something for office under 500")
    selected = record("office")
    assert_predicate selected.pending_order, :collecting_variant?
    assert_equal @office, selected.pending_order.product
    variant = record("15")
    assert_equal :variant_selected, variant.outcome
    assert_equal "15 ML", variant.pending_order.product_variant.size
    assert_predicate variant.pending_order, :collecting_quantity?
  end

  test "order history omits empty and unfinished drafts and includes all confirmed items" do
    result = record("3 office 10 ml + 2 party 15 ml")
    result.pending_order.update!(customer_name: "Test Customer", phone: "01700000000", address: "Test address", status: :awaiting_confirmation)
    record("confirm")
    record("new order")
    history = record("what was my previous order?")
    assert_includes history.bot_reply.content, "3 × The Office"
    assert_includes history.bot_reply.content, "2 × The Party"
    assert_no_match(/Product not selected|Collecting product/, history.bot_reply.content)
  end

  test "a model-only new-order classification cannot erase an active draft" do
    draft = record("The Office 15 ML 5 pieces den").pending_order
    message = draft.conversation.messages.create!(sender_type: :customer, content: "something else please")
    interpretation = AiIntentClassifier::Result.new(intent: "new_order", confidence: 0.99,
      entities: {}, language: "english", sentiment: "neutral", needs_clarification: false, possible_intents: [])
    processor = ConversationMessageProcessor.new(message: message, pending_order: draft, interpretation: interpretation)
    processor.process
    assert_equal 2400.to_d, draft.reload.total_price
    assert_equal @office.id, draft.product_id
    assert_not_equal :restarted, processor.outcome
  end

  test "unknown items in a shorthand list cannot partially replace the draft" do
    draft = record("The Office 15 ML 5 pieces den").pending_order
    result = record("3 office 10 ml + 2 unknown 15 ml")
    assert_equal :cart_needs_details, result.outcome
    assert_equal 2400.to_d, draft.reload.total_price
  end

  test "an unavailable shorthand list leaves the original cart intact" do
    draft = record("The Office 15 ML 5 pieces den").pending_order
    result = record("3 office 10 ml + 99 party 15 ml")
    assert_equal :cart_inventory_unavailable, result.outcome
    assert_equal 2400.to_d, draft.reload.total_price
  end

  test "ambiguous shorthand product names do not change the draft" do
    draft = record("The Party 15 ML 2 pieces den").pending_order
    @business.products.create!(name: "Office", price: 700, stock_quantity: 10)
    result = record("add office 10 ml 2 pieces")
    assert_equal :cart_needs_details, result.outcome
    assert_equal 1100.to_d, draft.reload.total_price
  end

  test "confirmed orders cannot be overwritten by shorthand lists" do
    draft = record("The Office 15 ML 5 pieces den").pending_order
    draft.update!(customer_name: "Test Customer", phone: "01700000000", address: "Test address", status: :awaiting_confirmation)
    record("confirm")
    result = record("3 office 10 ml + 2 party 15 ml")
    assert_equal :cart_locked, result.outcome
    assert_predicate draft.reload, :confirmed?
    assert_equal 2400.to_d, draft.total_price
  end

  private


  def record(content)
    CustomerMessageRecorder.new(business: @business, channel: "facebook", external_customer_id: @customer, content: content).record
  end
end
