require "test_helper"

class CartRepairAndTotalsTest < ActiveSupport::TestCase
  setup do
    @business = Business.create!(name: "Repair Shop", slug: "repair-shop")
    @oud = product("The Oud", { 15 => 580, 30 => 1000 })
    @club = product("The Club", { 10 => 390, 15 => 530 })
    @office = product("The Office", { 10 => 350, 30 => 850 })
    @customer = SecureRandom.uuid
  end

  test "named quantity correction preserves other cart items" do
    draft = record("The Oud 15 ml 2 ta ar The Office 30 ml 1 ta den").pending_order
    record("The Oud ekta koren")
    assert_equal 1430.to_d, draft.reload.total_price
    record("remove The Office")
    assert_equal 580.to_d, draft.reload.total_price
    assert_equal [ @oud.id ], draft.line_items.map(&:product_id)
    summary = record("ki ki ache ekhon?").bot_reply.content
    assert_includes summary, "The Oud"
    assert_not_includes summary, "The Office"
  end

  test "missing option repair retains all intended additions and original cart" do
    draft = record("The Office 10 ml ekta den").pending_order
    record("add The Oud ekta ar The Club 15 ml ekta")
    assert_equal 350.to_d, draft.reload.total_price
    record("Oud 30 ml")
    assert_equal 1880.to_d, draft.reload.total_price
    assert_equal 3, draft.line_items.size
    assert_nil draft.conversation.reload.conversation_state["cart_repair"]
  end

  test "unknown item requires explicit discard before known addition is applied" do
    draft = record("The Club 10 ml ekta den").pending_order
    record("add The Oud 15 ml ekta ar Moon Mist ekta")
    assert_equal 390.to_d, draft.reload.total_price
    record("The Oud 15 ml price?")
    assert_equal 390.to_d, draft.reload.total_price
    record("Moon Mist bad, shudhu Oud add koren")
    assert_equal 970.to_d, draft.reload.total_price
    assert_equal 2, draft.line_items.size
  end

  test "cart total reply reports sum rather than one product price" do
    draft = record("The Oud 15 ml 2 ta ar The Office 30 ml 1 ta den").pending_order
    result = record("total koto?")
    assert_equal :cart_total_requested, result.outcome
    assert_includes result.bot_reply.content, "2010"
    assert_equal 2010.to_d, draft.reload.total_price
  end

  test "incomplete summary asks for missing details rather than confirmation" do
    record("The Oud 15 ml ekta den")
    result = record("summary")
    assert_no_match(/Reply.*confirm/, result.bot_reply.content)
    assert_match(/name|nam/i, result.bot_reply.content)
    assert_nil result.pending_order.order
  end

  test "unresolved addition cannot confirm an otherwise complete draft" do
    draft = record("The Office 10 ml ekta den").pending_order
    draft.update!(customer_name: "Test Buyer", phone: "01700000000", address: "Test address", status: :awaiting_confirmation)
    record("add The Oud ekta ar The Club 15 ml ekta")
    result = record("confirm")
    assert_not_predicate draft.reload, :confirmed?
    assert_nil draft.order
    assert_equal :cart_needs_details, result.outcome
  end

  test "stock rejection keeps original cart and pending repair" do
    draft = record("The Office 10 ml ekta den").pending_order
    record("add The Oud 99 ta ar The Club 15 ml ekta")
    record("Oud 30 ml")
    assert_equal 350.to_d, draft.reload.total_price
    assert_equal :cart_inventory_unavailable, record("Oud 30 ml 99 ta").outcome
    assert_equal 350.to_d, draft.reload.total_price
  end

  private

  def product(name, prices)
    @business.products.create!(name: name, price: prices.values.first, stock_quantity: 20).tap do |product|
      prices.each { |size, price| product.product_variants.create!(name: "#{size} ML", size: "#{size} ML", price: price, stock_quantity: 20) }
    end
  end

  def record(content)
    CustomerMessageRecorder.new(business: @business, channel: "facebook", external_customer_id: @customer, content: content).record
  end
end
