require "test_helper"

class BotReplyGeneratorTest < ActiveSupport::TestCase
  test "asks customer to choose from available products" do
    Product.create!(name: "Fresh Musk", price: 750, stock_quantity: 10)
    Product.create!(name: "Royal Oud", price: 1200, stock_quantity: 4)
    Product.create!(name: "Inactive Product", price: 500, stock_quantity: 10, active: false)
    pending_order = create_pending_order(status: :collecting_product)

    reply = BotReplyGenerator.new(pending_order: pending_order).content

    assert_includes reply, "What would you like to order?"
    assert_includes reply, "Fresh Musk"
    assert_includes reply, "Royal Oud"
    assert_not_includes reply, "Inactive Product"
  end

  test "asks for quantity after product selection" do
    product = create_product(name: "Fresh Musk")
    pending_order = create_pending_order(product: product, status: :collecting_quantity)

    assert_equal(
      "Fresh Musk is ৳750 per bottle. How many would you like?",
      BotReplyGenerator.new(pending_order: pending_order).content
    )
  end

  test "asks for product when collecting quantity has no product yet" do
    Product.create!(name: "Fresh Musk", price: 750, stock_quantity: 10)
    pending_order = create_pending_order(status: :collecting_quantity)

    reply = BotReplyGenerator.new(pending_order: pending_order).content

    assert_includes reply, "What would you like to order?"
    assert_includes reply, "Fresh Musk"
  end

  test "asks for name after quantity" do
    pending_order = create_pending_order(status: :collecting_name)

    assert_equal(
      "What name should I put on the order?",
      BotReplyGenerator.new(pending_order: pending_order).content
    )
  end

  test "asks for phone after name" do
    pending_order = create_pending_order(status: :collecting_phone, customer_name: "Khaled")

    assert_equal(
      "What phone number should we use for the delivery?",
      BotReplyGenerator.new(pending_order: pending_order).content
    )
  end

  test "asks for address after phone" do
    pending_order = create_pending_order(status: :collecting_address)

    assert_equal(
      "What’s the full delivery address?",
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

    assert_includes reply, "Here’s your order summary:"
    assert_includes reply, "2 × Fresh Musk"
    assert_includes reply, "Total: ৳1500"
    assert_includes reply, "Name: Khaled"
    assert_includes reply, "Phone: +8801712345678"
    assert_includes reply, "Address: Dhaka"
  end

  test "confirms submitted order message" do
    pending_order = create_pending_order(status: :confirmed)

    assert_equal(
      "Your order is already confirmed ✅",
      BotReplyGenerator.new(pending_order: pending_order).content
    )
  end

  test "confirms cancelled order message" do
    pending_order = create_pending_order(status: :cancelled)

    assert_equal(
      "This order is cancelled. Send “new order” whenever you’d like to begin again.",
      BotReplyGenerator.new(pending_order: pending_order).content
    )
  end

  test "greets the customer and keeps the current prompt" do
    Product.create!(name: "Fresh Musk", price: 750, stock_quantity: 10)
    pending_order = create_pending_order(status: :collecting_product)

    reply = BotReplyGenerator.new(pending_order: pending_order, outcome: :greeting).content

    assert_includes reply, "Assalamu alaikum! 👋 Welcome to ChatCart."
    assert_includes reply, "Fresh Musk (৳750)"
  end

  test "explains invalid phone input" do
    pending_order = create_pending_order(status: :collecting_phone)

    reply = BotReplyGenerator.new(pending_order: pending_order, outcome: :invalid_phone).content

    assert_includes reply, "doesn’t look like a complete phone number"
    assert_includes reply, "01712345678"
  end

  test "answers a product price question without changing the order" do
    product = create_product(name: "Fresh Musk", price: 750)
    pending_order = create_pending_order(status: :collecting_product)
    message = pending_order.conversation.messages.create!(sender_type: :customer, content: "Price of Fresh Musk?")

    reply = BotReplyGenerator.new(
      pending_order: pending_order,
      customer_message: message,
      outcome: :price_inquiry
    ).content

    assert_includes reply, "Fresh Musk is ৳750 per bottle."
    assert_nil pending_order.reload.product
    assert product.persisted?
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
