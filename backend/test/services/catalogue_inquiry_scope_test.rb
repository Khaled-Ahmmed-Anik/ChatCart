require "test_helper"

class CatalogueInquiryScopeTest < ActiveSupport::TestCase
  setup do
    @business = Business.create!(name: "Scoped Shop", slug: "inquiry-scope", category: "electronics")
    @buds = @business.products.create!(name: "Hoco EQ34 Plus", category: "earbuds", price: 729, stock_quantity: 10)
    @tracker = @business.products.create!(name: "Hoco E103 Tracker", category: "tracker", price: 799, stock_quantity: 10)
    @case = @business.products.create!(name: "AirPods Pro 2 Protective Case", category: "case", price: 299, stock_quantity: 10)
    @customer = SecureRandom.uuid
  end

  test "brand price question returns only matching products without choosing one" do
    result = record("hoco tar price koto?")
    assert_includes result.bot_reply.content, @buds.name
    assert_includes result.bot_reply.content, @tracker.name
    assert_not_includes result.bot_reply.content, @case.name
    assert_nil result.pending_order.product_id
  end

  test "singular product token matches the plural catalogue name without claiming a device" do
    result = record("airpod ase?")
    assert_includes result.bot_reply.content, @case.name
    assert_not_includes result.bot_reply.content, @tracker.name
    assert_match(/accessory|অ্যাক্সেসরি/i, result.bot_reply.content)
    assert_nil result.pending_order.product_id
  end

  test "category qualifier narrows brand candidates and never leaks another business" do
    foreign = Business.create!(name: "Foreign", slug: "inquiry-foreign")
    foreign.products.create!(name: "Hoco Secret Earbuds", category: "earbuds", price: 1, stock_quantity: 10)
    products = CatalogueInquiryScope.new(business: @business, text: "hoco earbuds price?").products
    assert_equal [ @buds.id ], products.map(&:id)
  end

  private

  def record(content)
    CustomerMessageRecorder.new(business: @business, channel: "facebook", external_customer_id: @customer, content: content).record
  end
end
