require "test_helper"

class BotReplyGeneratorTest < ActiveSupport::TestCase
  test "asks customer to choose from available products" do
    Product.create!(name: "Fresh Musk", price: 750, stock_quantity: 10)
    Product.create!(name: "Royal Oud", price: 1200, stock_quantity: 4)
    Product.create!(name: "Inactive Product", price: 500, stock_quantity: 10, active: false)
    pending_order = create_pending_order(status: :collecting_product)

    reply = BotReplyGenerator.new(pending_order: pending_order).content

    assert_includes reply, "Here are our available products:"
    assert_includes reply, "• Fresh Musk — ৳750"
    assert_includes reply, "• Royal Oud — ৳1200"
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

  test "explains size tradeoffs instead of only listing variants" do
    product = create_product(name: "The Office", stock_quantity: 0)
    product.product_variants.create!(name: "30 ML", size: "30 ML", price: 850, stock_quantity: 10, position: 1)
    product.product_variants.create!(name: "10 ML", size: "10 ML", price: 350, stock_quantity: 10, position: 3)
    product.product_variants.create!(name: "15 ML", size: "15 ML", price: 480, stock_quantity: 10, position: 2)
    pending_order = create_pending_order(product: product, status: :collecting_variant)

    reply = BotReplyGenerator.new(pending_order: pending_order).content

    assert_operator reply.index("10 ML"), :<, reply.index("15 ML")
    assert_operator reply.index("15 ML"), :<, reply.index("30 ML")
    assert_includes reply, "good for trying it first"
    assert_includes reply, "best value for regular use"
    assert_includes reply, "reply with the size, price"
  end

  test "asks for product when collecting quantity has no product yet" do
    Product.create!(name: "Fresh Musk", price: 750, stock_quantity: 10)
    pending_order = create_pending_order(status: :collecting_quantity)

    reply = BotReplyGenerator.new(pending_order: pending_order).content

    assert_includes reply, "Here are our available products:"
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
    assert_includes reply, "Here are a few products you can order:"
    assert_includes reply, "• Fresh Musk — ৳750"
    assert_includes reply, "single perfume or combo"
  end

  test "limits the greeting catalog and explains how to see the rest" do
    8.times do |index|
      Product.create!(name: "Product #{index + 1}", price: 500 + index, stock_quantity: 10)
    end
    pending_order = create_pending_order(status: :collecting_product)

    reply = BotReplyGenerator.new(pending_order: pending_order, outcome: :greeting).content

    assert_equal 6, reply.lines.count { |line| line.start_with?("• Product") }
    assert_includes reply, "• +2 more available"
    assert_includes reply, "show all products"
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

  test "compares the products named by the customer using useful buying differences" do
    office = create_product(
      name: "The Office", price: 350,
      product_attributes: { scent_families: %w[fresh aquatic], occasions: %w[office daily], longevity_hours: "6-8", projection: "moderate" }
    )
    bleu = create_product(
      name: "Bleu Inspired", price: 400,
      product_attributes: { scent_families: %w[fresh woody], occasions: %w[office evening], longevity_hours: "8-10", projection: "strong" }
    )
    create_product(name: "Unrelated Product", price: 300)
    pending_order = create_pending_order(status: :collecting_product)
    message = pending_order.conversation.messages.create!(
      sender_type: :customer,
      content: "What is the difference between The Office and Bleu Inspired?"
    )

    reply = BotReplyGenerator.new(
      pending_order: pending_order,
      customer_message: message,
      outcome: :product_comparison_requested
    ).content

    assert_includes reply, "The Office — from ৳350"
    assert_includes reply, "fresh and aquatic"
    assert_includes reply, "Bleu Inspired — from ৳400"
    assert_includes reply, "8-10 hours"
    assert_not_includes reply, "Unrelated Product"
    assert office.persisted? && bleu.persisted?
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
