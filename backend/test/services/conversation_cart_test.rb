require "test_helper"

class ConversationCartTest < ActiveSupport::TestCase
  setup do
    @business = Business.create!(name: "Cart Shop", slug: "cart-shop", category: "clothing")
    @shirt = @business.products.create!(name: "Cotton Shirt", price: 600, stock_quantity: 20)
    @bag = @business.products.create!(name: "Canvas Bag", price: 450, stock_quantity: 10)
    @customer = SecureRandom.uuid
  end

  test "captures two different products with one set of customer details" do
    result = record("Cotton Shirt 2 pieces and Canvas Bag 1 piece den")
    assert_equal :cart_updated, result.outcome
    assert_equal 2, result.pending_order.line_items.size
    assert_equal 1650.to_d, result.pending_order.total_price
    assert_includes result.bot_reply.content, "Cotton Shirt"
    assert_includes result.bot_reply.content, "Canvas Bag"

    record("Anik")
    record("01725126467")
    summary = record("Badda Dhaka")
    assert_predicate summary.pending_order, :awaiting_confirmation?
    assert_includes summary.bot_reply.content, "2 × Cotton Shirt"
    assert_includes summary.bot_reply.content, "1 × Canvas Bag"

    confirmed = record("confirm")
    order = confirmed.pending_order.reload.order
    assert_equal 2, order.order_items.count
    assert_equal 1650.to_d, order.total
    assert_equal({ "Cotton Shirt" => 2, "Canvas Bag" => 1 }, order.order_items.pluck(:product_name, :quantity).to_h)
  end

  test "adds another product without losing customer details" do
    first = record("Cotton Shirt 2 pieces den")
    record("Anik")
    added = record("add Canvas Bag 1 piece")
    assert_equal :cart_updated, added.outcome
    assert_equal "Anik", added.pending_order.customer_name
    assert_predicate added.pending_order, :collecting_phone?
    assert_equal 1650.to_d, added.pending_order.total_price
    assert_equal first.pending_order.id, added.pending_order.id
  end

  test "adds a product progressively and asks for its missing option" do
    @bag.product_variants.create!(name: "Blue", size: "Blue", price: 500, stock_quantity: 5)
    record("Cotton Shirt 2 pieces den")
    added = record("add Canvas Bag")
    assert_predicate added.pending_order, :collecting_variant?
    assert_equal 1, added.pending_order.pending_order_items.count
    record("Blue")
    finished = record("1")
    assert_equal 1700.to_d, finished.pending_order.total_price
    assert_equal 2, finished.pending_order.line_items.size
  end

  test "named item quantity changes and removals preserve the rest of the cart" do
    record("Cotton Shirt 2 pieces and Canvas Bag 1 piece den")
    updated = record("change Cotton Shirt to 3 pieces")
    assert_equal :cart_updated, updated.outcome
    assert_equal 2250.to_d, updated.pending_order.total_price
    removed = record("remove Canvas Bag")
    assert_equal 1, removed.pending_order.line_items.size
    assert_equal @shirt.id, removed.pending_order.product_id
    assert_equal 3, removed.pending_order.quantity
    assert_equal 1800.to_d, removed.pending_order.total_price
  end

  test "same product and variant quantities are merged and checked together" do
    record("Cotton Shirt 2 pieces den")
    result = record("add Cotton Shirt 3 pieces")
    assert_equal 1, result.pending_order.line_items.size
    assert_equal 5, result.pending_order.line_items.first.quantity
    rejected = record("add Cotton Shirt 18 pieces")
    assert_equal :cart_inventory_unavailable, rejected.outcome
    assert_equal 5, rejected.pending_order.line_items.first.quantity
  end

  test "a multi-product request fails atomically when an option or stock is missing" do
    @bag.update!(stock_quantity: 0)
    result = record("Cotton Shirt 2 pieces and Canvas Bag 1 piece den")
    assert_equal :cart_inventory_unavailable, result.outcome
    assert_empty result.pending_order.line_items
    assert_nil result.pending_order.product_id
  end

  test "confirmation rechecks stock for saved items" do
    record("Cotton Shirt 2 pieces and Canvas Bag 1 piece den")
    record("Anik")
    record("01725126467")
    record("Badda Dhaka")
    @shirt.update!(stock_quantity: 1)
    result = record("confirm")
    assert_equal :cart_inventory_unavailable, result.outcome
    assert_predicate result.pending_order, :awaiting_confirmation?
    assert_nil result.pending_order.order
  end

  test "new order starts with an empty cart" do
    record("Cotton Shirt 2 pieces and Canvas Bag 1 piece den")
    result = record("new order")
    assert_empty result.pending_order.line_items
  end

  test "repeat order copies all previous products" do
    record("Cotton Shirt 2 pieces and Canvas Bag 1 piece den")
    record("Anik")
    record("01725126467")
    record("Badda Dhaka")
    record("confirm")
    result = record("repeat my order")
    assert_equal 2, result.pending_order.line_items.size
    assert_equal 1650.to_d, result.pending_order.total_price
    assert_predicate result.pending_order, :awaiting_confirmation?
  end

  test "foreign-business products cannot be attached to a draft" do
    other = Business.create!(name: "Other Cart", slug: "other-cart")
    product = other.products.create!(name: "Foreign Shirt", price: 50, stock_quantity: 5)
    result = record("Cotton Shirt 2 pieces den")
    item = result.pending_order.pending_order_items.build(product: product, quantity: 1)
    assert_not item.valid?
  end

  test "two options of the same product remain separate cart lines" do
    @shirt.product_variants.create!(name: "Large", size: "L", price: 650, stock_quantity: 10)
    @shirt.product_variants.create!(name: "Medium", size: "M", price: 600, stock_quantity: 10)
    result = record("Cotton Shirt Large 2 pieces and Cotton Shirt Medium 1 piece den")
    assert_equal :cart_updated, result.outcome
    assert_equal 2, result.pending_order.line_items.size
    assert_equal 1900.to_d, result.pending_order.total_price
    unclear = record("change Cotton Shirt to 3")
    assert_equal :cart_needs_details, unclear.outcome
    assert_equal 1900.to_d, unclear.pending_order.total_price
  end

  test "an unknown second product is not silently discarded" do
    result = record("Cotton Shirt 2 pieces and Unknown Shoe 1 piece den")
    assert_equal :cart_needs_details, result.outcome
    assert_empty result.pending_order.line_items
  end

  test "changing a named saved item accepts a bare quantity" do
    record("Cotton Shirt 2 pieces and Canvas Bag 1 piece den")
    result = record("change Cotton Shirt to 3")
    assert_equal :cart_updated, result.outcome
    assert_equal 2250.to_d, result.pending_order.total_price
  end

  private

  def record(content)
    CustomerMessageRecorder.new(business: @business, channel: "facebook", external_customer_id: @customer, content: content).record
  end
end
