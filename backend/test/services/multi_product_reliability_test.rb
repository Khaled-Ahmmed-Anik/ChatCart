require "test_helper"

class MultiProductReliabilityTest < ActiveSupport::TestCase
  setup do
    @business = Business.create!(name: "Multi Shop", slug: "multi-reliability", category: "electronics")
    @buds = @business.products.create!(name: "Hoco EQ34 Plus", category: "earbuds", price: 729, stock_quantity: 20)
    @charger = @business.products.create!(name: "Anker Nano Charger", category: "charger", price: 1849, stock_quantity: 20)
    @tracker = @business.products.create!(name: "Hoco E103 Tracker", category: "tracker", price: 799, stock_quantity: 20)
    @customer = SecureRandom.uuid
  end

  test "a new multi-product selection adds without silently replacing existing items" do
    order = record("Hoco E103 Tracker 1 piece den").pending_order
    record("Hoco EQ34 Plus 2 pieces and Anker Nano Charger 1 piece den")
    assert_equal({ @tracker.id => 1, @buds.id => 2, @charger.id => 1 }, quantities(order))
  end

  test "relative addition increments but correction sets the quantity" do
    order = record("Hoco EQ34 Plus 2 pieces and Anker Nano Charger 1 piece den").pending_order
    record("aro ekta earbuds")
    assert_equal({ @buds.id => 3, @charger.id => 1 }, quantities(order))
    record("change Hoco EQ34 Plus to 1 piece")
    assert_equal({ @buds.id => 1, @charger.id => 1 }, quantities(order))
    record("remove Anker Nano Charger")
    assert_equal({ @buds.id => 1 }, quantities(order))
  end

  test "explicit cart replacement is atomic and preserves customer details" do
    order = record("Hoco E103 Tracker 1 piece den").pending_order
    order.update!(customer_name: "Test Buyer")
    record("replace cart with Hoco EQ34 Plus 2 pieces and Anker Nano Charger 1 piece")
    assert_equal({ @buds.id => 2, @charger.id => 1 }, quantities(order))
    assert_equal "Test Buyer", order.customer_name
    record("replace cart with Hoco E103 Tracker 99 pieces and Anker Nano Charger 1 piece")
    assert_equal({ @buds.id => 2, @charger.id => 1 }, quantities(order))
  end

  test "an ambiguous category addition cannot choose between existing variants or products" do
    @tracker.update!(category: "earbuds")
    order = record("Hoco EQ34 Plus 2 pieces and Hoco E103 Tracker 1 piece den").pending_order
    before = quantities(order)
    result = record("aro ekta earbuds")
    assert_equal :cart_needs_details, result.outcome
    assert_equal before, quantities(order)
  end

  test "unknown products at the beginning or middle cannot partially change the cart" do
    [ "add Mystery Device 1 piece and Hoco EQ34 Plus 2 pieces",
      "add Hoco EQ34 Plus 2 pieces and Mystery Device 1 piece and Anker Nano Charger 1 piece" ].each do |text|
      @customer = SecureRandom.uuid
      order = record("Hoco E103 Tracker 1 piece den").pending_order
      result = record(text)
      assert_equal :cart_needs_details, result.outcome
      assert_equal({ @tracker.id => 1 }, quantities(order))
    end
  end

  test "a negative quantity must not become a positive addition during normalization" do
    order = record("Hoco EQ34 Plus 2 pieces den").pending_order
    result = record("add Hoco EQ34 Plus -2 pieces")
    assert_equal :cart_needs_details, result.outcome
    assert_equal({ @buds.id => 2 }, quantities(order))
  end

  test "an explicitly requested single-product replacement removes the old cart" do
    order = record("Hoco EQ34 Plus 2 pieces and Anker Nano Charger 1 piece den").pending_order
    record("replace cart with Hoco E103 Tracker 1 piece")
    assert_equal({ @tracker.id => 1 }, quantities(order))
  end

  private

  def quantities(order)
    order.reload.line_items.to_h { |item| [ item.product_id, item.quantity ] }
  end

  def record(content)
    CustomerMessageRecorder.new(business: @business, channel: "facebook", external_customer_id: @customer, content: content).record
  end
end
