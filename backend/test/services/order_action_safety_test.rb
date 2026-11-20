require "test_helper"

class OrderActionSafetyTest < ActiveSupport::TestCase
  setup do
    @business = Business.create!(name: "Device Shop", slug: "action-safety", category: "electronics")
    @product = @business.products.create!(name: "Hoco EQ34 Plus", price: 729, stock_quantity: 100)
    @conversation = @business.conversations.create!(channel: "facebook", external_customer_id: "safety")
    @order = @conversation.create_pending_order!
  end

  test "model numbers never become implicit quantities" do
    result = process("Hoco EQ34 Plus nibo")
    assert_equal :product_selected, result.outcome
    assert_equal @product, @order.reload.product
    assert_nil @order.quantity
    assert_predicate @order, :collecting_quantity?
    assert_equal 2, ConversationQuantityParser.call("2 ta Hoco EQ34 Plus", products: [ @product ])
    assert_nil ConversationQuantityParser.call("Hoco EQ34 Plus", products: [ @product ])
    assert_nil ConversationQuantityParser.call("45W, 7 hours, 1000 taka")
  end

  test "factual questions cannot begin checkout or add cart items" do
    [ "Tell me specifically about Hoco EQ34 Plus battery.", "Does Hoco EQ34 Plus include a cable?" ].each do |text|
      process(text)
      assert_nil @order.reload.product_id
      assert_nil @order.quantity
      assert_empty @order.pending_order_items
    end
  end

  test "cancel works across all unconfirmed checkout stages" do
    %w[collecting_product collecting_variant collecting_quantity collecting_name collecting_phone collecting_address awaiting_confirmation].each do |stage|
      [ "cancel", "Cancel this test order.", "Puro test order cancel koren." ].each do |text|
        @order.update!(status: stage)
        assert_equal :cancelled, process(text).outcome, "#{stage}: #{text}"
        assert_predicate @order.reload, :cancelled?
      end
    end
  end

  test "quantity corrections accept punctuation and Banglish without trusting a classifier" do
    @order.update!(product: @product, quantity: 34, status: :collecting_name)
    assert_equal :order_updated, process("Actually change the quantity to 2.").outcome
    assert_equal 2, @order.reload.quantity
    assert_equal :order_updated, process("Quantity 3 ta kore den.").outcome
    assert_equal 3, @order.reload.quantity
  end

  private

  def process(text)
    message = @conversation.messages.create!(sender_type: :customer, content: text)
    ConversationMessageProcessor.new(message: message, pending_order: @order.reload).tap(&:process)
  end
end
