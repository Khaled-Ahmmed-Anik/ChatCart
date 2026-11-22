require "test_helper"

class ConversationContextReliabilityTest < ActiveSupport::TestCase
  setup do
    @business = Business.create!(name: "Context Shop", slug: "context-reliability", category: "electronics")
    @product = @business.products.create!(name: "Hoco EQ34 Plus", price: 729, stock_quantity: 20,
      description: "USB Type-C charging.")
    @customer = SecureRandom.uuid
  end

  test "delivery spelling variations cannot become product charging answers" do
    record("Hoco EQ34 Plus 1 piece den")
    [ "Dalivery charge koto", "delivery chage koto", "delivary chrage koto" ].each do |text|
      result = record(text)
      assert_equal :delivery_charge_requested, result.outcome, text
      assert_no_match(/USB|Type-C/, result.bot_reply.content)
      assert_equal @product.id, result.pending_order.product_id
      assert_equal 1, result.pending_order.quantity
    end
  end

  test "confirmation plus delivery question does not finalize the order" do
    order = record("Hoco EQ34 Plus 1 piece den").pending_order
    order.update!(customer_name: "Test", phone: "01700000000", address: "Test address", status: :awaiting_confirmation)
    result = record("confirm, delivery chage koto")
    assert_equal :delivery_charge_requested, result.outcome
    assert_predicate order.reload, :awaiting_confirmation?
    assert_empty @business.orders
    assert_equal :confirmed, record("confirm").outcome
    assert_equal 1, @business.orders.count
  end

  test "contextual acknowledgement and order instructions preserve the discussed product" do
    record("Hoco EQ34 Plus price koto?")
    result = record("Hae hae eitai to")
    assert_includes result.bot_reply.content, @product.name
    assert_nil result.pending_order.product_id
    result = record("Hae kivabe order korbo?")
    assert_equal @product.id, result.pending_order.product_id
    assert_predicate result.pending_order, :collecting_quantity?
    assert_no_match(/new order|notun order|Here are our available/, result.bot_reply.content)
  end

  test "a delivery question after confirmation cannot mutate the order" do
    order = record("Hoco EQ34 Plus 1 piece den").pending_order
    order.update!(customer_name: "Test", phone: "01700000000", address: "Test address", status: :awaiting_confirmation)
    record("confirm")
    result = record("Dalivery charge koto")
    assert_equal :delivery_charge_requested, result.outcome
    assert_predicate order.reload, :confirmed?
    assert_equal 1, @business.orders.count
  end

  private

  def record(content)
    CustomerMessageRecorder.new(business: @business, channel: "facebook", external_customer_id: @customer, content: content).record
  end
end
