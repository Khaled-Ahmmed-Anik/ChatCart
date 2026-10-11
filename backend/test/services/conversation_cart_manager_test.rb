require "test_helper"

class ConversationCartManagerTest < ActiveSupport::TestCase
  test "short correction targets only a unique existing cart product" do
    product = Product.create!(name: "Cotton Shirt", price: 600, stock_quantity: 10)
    conversation = Conversation.create!(channel: "facebook", external_customer_id: "short-cart-correction")
    order = conversation.pending_orders.create!(product: product, quantity: 2, status: :collecting_name)
    message = conversation.messages.create!(sender_type: :customer, content: "actually one shirt")
    result = ConversationCartManager.new(message: message, pending_order: order).call
    assert_equal :cart_updated, result.outcome
    assert_equal 1, order.reload.quantity
  end
end
