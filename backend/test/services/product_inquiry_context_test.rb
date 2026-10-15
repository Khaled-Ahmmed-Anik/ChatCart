require "test_helper"

class ProductInquiryContextTest < ActiveSupport::TestCase
  setup do
    @business = Business.create!(name: "Inquiry Shop", slug: "inquiry-shop")
    @oud = @business.products.create!(name: "The Oud", price: 420, stock_quantity: 20)
    @club = @business.products.create!(name: "The Club", price: 390, stock_quantity: 20)
    [ [ @oud, [ 420, 580, 1000 ] ], [ @club, [ 390, 530, 950 ] ] ].each do |product, prices|
      [ 10, 15, 30 ].zip(prices).each do |size, price|
        product.product_variants.create!(name: "#{size} ML", size: "#{size} ML", price: price, stock_quantity: 20)
      end
    end
    @customer = SecureRandom.uuid
  end

  test "Banglish price inquiry survives a delivery side question and size selection" do
    inquiry = record("oud er daam koto?")
    assert_nil inquiry.pending_order.product
    record("delivery charge koto?")
    choice = record("15 ml ta nibo")
    assert_equal @oud, choice.pending_order.product
    assert_equal "15 ML", choice.pending_order.product_variant.size
    record("ekta den")
    assert_equal 580.to_d, choice.pending_order.reload.total_price
  end

  test "bigger size question preserves inquiry without adding an item" do
    draft = record("The Oud 10 ml price?").pending_order
    response = record("bigger size ache?")
    assert_equal :product_variants_requested, response.outcome
    assert_includes response.bot_reply.content, "30 ML"
    assert_nil draft.reload.product
    choice = record("shobcheye boro ta ekta")
    assert_equal @oud, choice.pending_order.product
    assert_equal "30 ML", choice.pending_order.product_variant.size
    assert_equal 1, choice.pending_order.quantity
  end

  test "new named inquiry replaces the discussed product without changing checkout" do
    record("The Oud price?")
    record("The Club price?")
    choice = record("30 ml ekta den")
    assert_equal @club, choice.pending_order.product
    assert_equal 950.to_d, choice.pending_order.total_price
  end

  test "relative purchase uses the next size after the size discussed" do
    record("The Oud 10 ml price?")
    choice = record("bigger ta ekta")
    assert_equal "15 ML", choice.pending_order.product_variant.size
    assert_equal 1, choice.pending_order.quantity
  end

  test "short size and Banglish quantity complete the discussed product" do
    record("club er daam koto?")
    record("30 ml")
    choice = record("ektai den")
    assert_equal @club, choice.pending_order.product
    assert_equal "30 ML", choice.pending_order.product_variant.size
    assert_equal 950.to_d, choice.pending_order.total_price
  end

  test "new order cannot use a previous inquiry" do
    record("The Oud price?")
    record("new order")
    choice = record("15 ml ta nibo")
    assert_nil choice.pending_order.product
  end

  test "archived product cannot be selected from inquiry memory" do
    record("The Oud price?")
    @oud.update!(active: false)
    choice = record("15 ml ta nibo")
    assert_nil choice.pending_order.product
  end

  test "asking about another product does not overwrite an existing cart" do
    draft = record("The Club 15 ml ekta den").pending_order
    record("The Oud price?")
    record("30 ml ta nibo")
    assert_equal @club, draft.reload.product
  end

  test "unknown named inquiry cannot leave a previous product as the default" do
    record("The Oud price?")
    record("Unknown Widget price?")
    assert_nil ConversationProductInquiry.new(record("15 ml ta nibo").pending_order).product
  end

  test "catalogue browsing clears the single product inquiry" do
    record("The Oud price?")
    record("show all products")
    assert_nil record("15 ml ta nibo").pending_order.product
  end

  test "inquiry IDs cannot cross business boundaries" do
    draft = record("The Oud price?").pending_order
    other = Business.create!(name: "Other Inquiry Shop", slug: "other-inquiry-shop")
    outsider = other.products.create!(name: "The Oud", price: 9999, stock_quantity: 10)
    draft.conversation.update!(conversation_state: { "product_inquiry" => { "product_id" => outsider.id, "pending_order_id" => draft.id } })
    assert_nil ConversationProductInquiry.new(draft).product
  end

  private

  def record(content)
    CustomerMessageRecorder.new(business: @business, channel: "facebook", external_customer_id: @customer, content: content).record
  end
end
