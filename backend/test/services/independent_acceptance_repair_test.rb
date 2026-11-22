require "test_helper"

class IndependentAcceptanceRepairTest < ActiveSupport::TestCase
  setup do
    @business = Business.create!(name: "Acceptance Repair", slug: "acceptance-repair", category: "retail")
    @buds = @business.products.create!(name: "Hoco EQ34 Plus", aliases: [ "earbuds", "ইয়ারবাড" ], category: "earbuds", price: 729, stock_quantity: 10,
      product_attributes: { catalogue_facts: { warranty: "6 months seller warranty" } })
    @charger = @business.products.create!(name: "Anker Nano Charger", aliases: [ "charger", "চার্জার" ], category: "charger", price: 1849, stock_quantity: 10)
    @shirt = @business.products.create!(name: "Cotton Shirt", category: "clothing", price: 550, stock_quantity: 10)
    @blue = @shirt.product_variants.create!(name: "Blue L", size: "L", price: 550, stock_quantity: 10)
    @shirt.product_variants.create!(name: "Red M", size: "M", price: 600, stock_quantity: 10)
    @business.policy.update!(delivery_charges: "Delivery charge: ৳80", delivery_time: "2–3 days", cash_on_delivery: "Cash on delivery is available")
    @customer = SecureRandom.uuid
  end

  test "Bengali multi-product quantities remain attached to their own products" do
    order = record("ইয়ারবাড ২টা আর চার্জার ১টা চাই").pending_order
    assert_equal({ @buds.id => 2, @charger.id => 1 }, quantities(order))
    result = record("সব মিলিয়ে কত টাকা?")
    assert_includes result.bot_reply.content, "3307"
    assert_equal({ @buds.id => 2, @charger.id => 1 }, quantities(order))
  end

  test "polite and Bengali removal target the cart instead of shortlist or pause" do
    [ "Please remove the charger from my order.", "চার্জারটা বাদ দিন" ].each do |text|
      @customer = SecureRandom.uuid
      order = record("add earbuds 2 pieces and charger 1 piece").pending_order
      result = record(text)
      assert_equal :cart_updated, result.outcome
      assert_equal({ @buds.id => 2 }, quantities(order))
    end
  end

  test "Bengali quantity correction changes only the named line" do
    order = record("add earbuds 2 pieces and charger 1 piece").pending_order
    record("ইয়ারবাড ৩টা করুন")
    assert_equal({ @buds.id => 3, @charger.id => 1 }, quantities(order))
  end

  test "Bengali unknown addition cannot partially apply a cart change" do
    order = record("earbuds 1 piece den").pending_order
    result = record("Mystery Adapter ১টা আর চার্জার ১টা যোগ করুন")
    assert_equal :cart_needs_details, result.outcome
    assert_equal({ @buds.id => 1 }, quantities(order))
    assert_nil order.order
  end

  test "plural product name retains its requested variant and quantity" do
    order = record("Please order two Cotton Shirts in Blue L.").pending_order
    assert_equal @shirt.id, order.product_id
    assert_equal @blue.id, order.product_variant_id
    assert_equal 2, order.quantity
  end

  test "negated Bengali cart commands do not add or remove items" do
    order = record("add earbuds 2 pieces and charger 1 piece").pending_order
    [ "চার্জারটা বাদ দেবেন না", "ইয়ারবাড ৩টা যোগ করবেন না" ].each do |text|
      record(text)
      assert_equal({ @buds.id => 2, @charger.id => 1 }, quantities(order))
    end
  end

  private

  def quantities(order)
    order.reload.line_items.to_h { |item| [ item.product_id, item.quantity ] }
  end

  def record(content)
    CustomerMessageRecorder.new(business: @business, channel: "facebook", external_customer_id: @customer, content: content).record
  end
end
