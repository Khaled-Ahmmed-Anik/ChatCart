require "test_helper"

class BotReplyGeneratorTest < ActiveSupport::TestCase
  test "asks customer to choose from available products" do
    Product.create!(name: "Fresh Musk", price: 750, stock_quantity: 10)
    Product.create!(name: "Royal Oud", price: 1200, stock_quantity: 4)
    Product.create!(name: "Inactive Product", price: 500, stock_quantity: 10, active: false)
    pending_order = create_pending_order(status: :collecting_product)

    reply = BotReplyGenerator.new(pending_order: pending_order).content

    assert_includes reply, "Which product would you like?"
    assert_includes reply, "Fresh Musk"
    assert_includes reply, "Royal Oud"
    assert_not_includes reply, "Inactive Product"
  end

  test "asks for quantity after product selection" do
    product = create_product(name: "Fresh Musk")
    pending_order = create_pending_order(product: product, status: :collecting_quantity)

    assert_equal(
      "Great choice. How many bottles of Fresh Musk would you like?",
      BotReplyGenerator.new(pending_order: pending_order).content
    )
  end

  test "asks for product when collecting quantity has no product yet" do
    Product.create!(name: "Fresh Musk", price: 750, stock_quantity: 10)
    pending_order = create_pending_order(status: :collecting_quantity)

    reply = BotReplyGenerator.new(pending_order: pending_order).content

    assert_includes reply, "Which product would you like?"
    assert_includes reply, "Fresh Musk"
  end

  test "asks for name after quantity" do
    pending_order = create_pending_order(status: :collecting_name)

    assert_equal(
      "Perfect. Please share your name for the order.",
      BotReplyGenerator.new(pending_order: pending_order).content
    )
  end

  test "asks for phone after name" do
    pending_order = create_pending_order(status: :collecting_phone, customer_name: "Khaled")

    assert_equal(
      "Thanks, Khaled. Please share your phone number.",
      BotReplyGenerator.new(pending_order: pending_order).content
    )
  end

  test "asks for address after phone" do
    pending_order = create_pending_order(status: :collecting_address)

    assert_equal(
      "Got it. Please share your delivery address.",
      BotReplyGenerator.new(pending_order: pending_order).content
    )
  end

  test "summarizes order while awaiting confirmation" do
    pending_order = create_pending_order(
      product: create_product(name: "Fresh Musk", price: 750),
      quantity: 2,
      customer_name: "Khaled",
      phone: "+8801712345678",
      address: "Dhaka",
      status: :awaiting_confirmation
    )

    reply = BotReplyGenerator.new(pending_order: pending_order).content

    assert_includes reply, "Please confirm your order:"
    assert_includes reply, "2 x Fresh Musk"
    assert_includes reply, "Total: 1500.0"
    assert_includes reply, "Name: Khaled"
    assert_includes reply, "Phone: +8801712345678"
    assert_includes reply, "Address: Dhaka"
  end

  private

  def create_pending_order(attributes = {})
    conversation = Conversation.create!(channel: "facebook", external_customer_id: SecureRandom.uuid)
    conversation.create_pending_order!(attributes)
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
