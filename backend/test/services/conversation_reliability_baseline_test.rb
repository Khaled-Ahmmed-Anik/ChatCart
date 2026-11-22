require "test_helper"

class ConversationReliabilityBaselineTest < ActiveSupport::TestCase
  setup do
    @business = Business.create!(name: "Reliability Shop", slug: "reliability-shop", category: "electronics")
    @earbuds = @business.products.create!(name: "Hoco EQ34 Plus", price: 729, stock_quantity: 20)
    @charger = @business.products.create!(name: "Anker Nano Charger", price: 1849, stock_quantity: 20)
    @customer = SecureRandom.uuid
  end

  test "explicit two-product quantities produce two independent cart lines" do
    order = record("Hoco EQ34 Plus 2 pieces and Anker Nano Charger 1 piece den").pending_order
    assert_equal({ @earbuds.id => 2, @charger.id => 1 }, order.line_items.to_h { |item| [ item.product_id, item.quantity ] })
    assert_equal 3307.to_d, order.total_price
  end

  test "delivery side question leaves both cart lines intact" do
    order = record("Hoco EQ34 Plus 2 pieces and Anker Nano Charger 1 piece den").pending_order
    before = order.line_items.map { |item| [ item.product_id, item.quantity ] }.sort
    record("delivery charge koto?")
    assert_equal before, order.reload.line_items.map { |item| [ item.product_id, item.quantity ] }.sort
    assert_not_predicate order, :confirmed?
  end

  private

  def record(content)
    CustomerMessageRecorder.new(business: @business, channel: "facebook", external_customer_id: @customer, content: content).record
  end
end
