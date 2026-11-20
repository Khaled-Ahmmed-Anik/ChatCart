require "test_helper"

class CartPreferenceContinuityTest < ActiveSupport::TestCase
  setup do
    @business = Business.create!(name: "Tech", slug: "cart-preferences", category: "electronics")
    @buds = @business.products.create!(name: "Hoco EQ34 Plus", category: "earbuds", price: 729, stock_quantity: 100)
    @tracker = @business.products.create!(name: "Hoco E103 Tiger Dual Anti-Lost Bluetooth Tracker", category: "tracker", price: 799, stock_quantity: 20)
    @watch = @business.products.create!(name: "Y80 Ultra Smartwatch", category: "smartwatch", price: 999, stock_quantity: 10)
    @customer = "cart-preferences"
  end

  test "one and ekta before partial model names create complete cart lines" do
    record("I want one Hoco EQ34 Plus")
    result = record("Also add one Hoco E103 tracker to the same order.")
    assert_equal 1528.to_d, result.pending_order.reload.total_price
    assert_equal 2, result.pending_order.line_items.size
    result = record("Ekta Y80 Ultra Smartwatch o add koren.")
    assert_equal 2527.to_d, result.pending_order.reload.total_price
    summary = record("What is in my cart now?")
    assert_includes summary.bot_reply.content, "Hoco EQ34"
    assert_includes summary.bot_reply.content, "Y80"
  end

  test "line category corrections and removals preserve other items" do
    record("Hoco EQ34 Plus 1 piece and Hoco E103 Tiger Dual Anti-Lost Bluetooth Tracker 1 piece den")
    result = record("Make the earbuds 2 pieces, keep the tracker one.")
    assert_equal 2257.to_d, result.pending_order.reload.total_price
    result = record("Remove the tracker only; keep the earbuds.")
    assert_equal 1458.to_d, result.pending_order.reload.total_price
    assert_equal [ @buds.id ], result.pending_order.line_items.map(&:product_id)
  end

  test "price quotes do not create checkout selections" do
    record("need earbuds")
    result = record("What is the total for two Hoco EQ34 Plus before delivery?")
    assert_includes result.bot_reply.content, "1458"
    assert_nil result.pending_order.reload.product_id
    assert_nil result.pending_order.quantity
  end

  test "budget changes and device memory survive category switches" do
    record("Samsung A54 er jonno 800 er moddhe earbuds chai")
    record("I can increase the budget to 2000")
    result = record("Now show smartwatch")
    assert_equal 2000.to_d, result.conversation.reload.conversation_state.dig("shopping_preferences", "maximum_price").to_d
    answer = record("What was my device model?")
    assert_includes answer.bot_reply.content, "Samsung A54"
  end

  private

  def record(text)
    CustomerMessageRecorder.new(business: @business, channel: "facebook", external_customer_id: @customer, content: text).record
  end
end
