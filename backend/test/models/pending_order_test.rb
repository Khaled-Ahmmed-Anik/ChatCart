require "test_helper"

class PendingOrderTest < ActiveSupport::TestCase
  test "belongs to a conversation" do
    pending_order = PendingOrder.new

    assert_not pending_order.valid?
    assert_includes pending_order.errors[:conversation], "must exist"
  end

  test "product is optional" do
    pending_order = PendingOrder.new(conversation: create_conversation)

    assert pending_order.valid?
  end

  test "defaults to collecting product status" do
    pending_order = PendingOrder.create!(conversation: create_conversation)

    assert_predicate pending_order, :collecting_product?
  end

  test "validates positive quantity when present" do
    pending_order = PendingOrder.new(conversation: create_conversation, quantity: 0)

    assert_not pending_order.valid?
    assert_includes pending_order.errors[:quantity], "must be greater than 0"
  end

  test "ready_for_confirmation requires product, quantity, customer name, phone, and address" do
    pending_order = PendingOrder.new(
      conversation: create_conversation,
      product: create_product,
      quantity: 1,
      customer_name: "Test Customer",
      phone: "0123456789",
      address: "Dhaka"
    )

    assert pending_order.ready_for_confirmation?

    pending_order.address = nil

    assert_not pending_order.ready_for_confirmation?
  end

  test "total_price returns zero without product or quantity" do
    pending_order = PendingOrder.new(conversation: create_conversation)

    assert_equal 0, pending_order.total_price
  end

  test "total_price multiplies product price by quantity" do
    pending_order = PendingOrder.new(
      conversation: create_conversation,
      product: create_product(price: 750),
      quantity: 2
    )

    assert_equal 1500.to_d, pending_order.total_price
  end

  private

  def create_conversation
    Conversation.create!(channel: "facebook", external_customer_id: SecureRandom.uuid)
  end

  def create_product(attributes = {})
    Product.create!(
      {
        name: "Fresh Musk",
        price: 750,
        stock_quantity: 10
      }.merge(attributes)
    )
  end
end
