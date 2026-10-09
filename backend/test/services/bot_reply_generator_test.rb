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
      "Fresh Musk is ৳750 each. How many would you like?",
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
    offered = pending_order.conversation.reload.conversation_state.fetch("last_offered_options")
    assert_equal "variants", offered["kind"]
    assert_equal [ "10 ML", "15 ML", "30 ML" ], offered["options"].pluck("label")
  end

  test "offers multiple bottles for a requested size above the largest option" do
    product = create_product(name: "The Oud", stock_quantity: 0)
    product.product_variants.create!(name: "10 ML", size: "10 ML", price: 350, stock_quantity: 10)
    product.product_variants.create!(name: "30 ML", size: "30 ML", price: 850, stock_quantity: 10)
    pending_order = create_pending_order(product: product, status: :collecting_variant)
    message = pending_order.conversation.messages.create!(sender_type: :customer, content: "100 ML ache?")
    processor = ConversationMessageProcessor.new(message: message, pending_order: pending_order)
    processor.process

    reply = BotReplyGenerator.new(
      pending_order: pending_order,
      customer_message: message,
      outcome: processor.outcome
    ).content

    assert_includes reply, "100 ML isn’t available as one bottle"
    assert_includes reply, "4 × 30 ML"
    assert_includes reply, "120 ML in total"
    assert_includes reply, "৳3400"
    assert_includes reply, "Would that work"
  end

  test "mentions both requested sizes when neither is sold as one bottle" do
    product = create_product(name: "The Club", stock_quantity: 0)
    product.product_variants.create!(name: "30 ML", size: "30 ML", price: 850, stock_quantity: 10)
    pending_order = create_pending_order(product: product, status: :collecting_variant)
    message = pending_order.conversation.messages.create!(sender_type: :customer, content: "50 or 100ml ase?")
    processor = ConversationMessageProcessor.new(message: message, pending_order: pending_order)
    processor.process

    reply = BotReplyGenerator.new(pending_order: pending_order, customer_message: message, outcome: processor.outcome).content

    assert_includes reply, "50 ML and 100 ML aren’t available as one bottle"
    assert_includes reply, "2 × 30 ML"
  end

  test "asks for a product name when a size question has no product context" do
    pending_order = create_pending_order(status: :collecting_product)
    message = pending_order.conversation.messages.create!(sender_type: :customer, content: "size options?")

    reply = BotReplyGenerator.new(
      pending_order: pending_order,
      customer_message: message,
      outcome: :product_variants_requested
    ).content

    assert_includes reply, "which product"
    assert_not_includes reply, "available products"
  end

  test "answers a size follow-up using the current product context" do
    product = create_product(name: "The Office", stock_quantity: 0)
    product.product_variants.create!(name: "10 ML", size: "10 ML", price: 350, stock_quantity: 5)
    product.product_variants.create!(name: "15 ML", size: "15 ML", price: 480, stock_quantity: 4)
    pending_order = create_pending_order(product: product, status: :collecting_variant)
    message = pending_order.conversation.messages.create!(sender_type: :customer, content: "what sizes are available?")

    reply = BotReplyGenerator.new(
      pending_order: pending_order,
      customer_message: message,
      outcome: :product_variants_requested
    ).content

    assert_includes reply, "The Office is available in:"
    assert_includes reply, "10 ML — ৳350"
    assert_includes reply, "15 ML — ৳480"
    assert_not_includes reply, "available products"
  end

  test "summarizes common sizes when the customer asks for general options" do
    first = create_product(name: "The Office", stock_quantity: 0)
    first.product_variants.create!(name: "10 ML", size: "10 ML", price: 350, stock_quantity: 5)
    second = create_product(name: "The Oud", stock_quantity: 0)
    second.product_variants.create!(name: "10 ML", size: "10 ML", price: 420, stock_quantity: 5)
    second.product_variants.create!(name: "15 ML", size: "15 ML", price: 600, stock_quantity: 4)
    pending_order = create_pending_order(status: :collecting_product)
    message = pending_order.conversation.messages.create!(sender_type: :customer, content: "general size options")

    reply = BotReplyGenerator.new(
      pending_order: pending_order,
      customer_message: message,
      outcome: :product_variants_requested
    ).content

    assert_includes reply, "common available size options"
    assert_includes reply, "10 ML — ৳350–৳420"
    assert_includes reply, "15 ML — ৳600"
    assert_not_includes reply, "which product"
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
    assert_includes reply, "any preferences, and your budget"
    assert_not_includes reply, "single perfume"
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
    offered = pending_order.conversation.reload.conversation_state.fetch("last_offered_options")
    assert_equal "products", offered["kind"]
    assert_equal 6, offered["options"].size
  end

  test "explains invalid phone input" do
    pending_order = create_pending_order(
      status: :collecting_phone, customer_name: "Anik", address: "Middle Badda"
    )

    reply = BotReplyGenerator.new(pending_order: pending_order, outcome: :invalid_phone).content

    assert_includes reply, "Please send a complete Bangladesh phone number"
    assert_includes reply, "01712345678"
    assert_includes reply, "Saved so far: name and address"
  end

  test "offers a useful bulk-order recovery when requested quantity exceeds stock" do
    product = create_product(stock_quantity: 100)
    pending_order = create_pending_order(product: product, status: :collecting_quantity)

    reply = BotReplyGenerator.new(pending_order: pending_order, outcome: :quantity_unavailable).content

    assert_includes reply, "all 100"
    assert_includes reply, "smaller quantity"
    assert_includes reply, "bulk order"
  end

  test "answers a Banglish performance follow-up about the remembered product" do
    product = create_product(
      name: "The Club",
      product_attributes: { longevity_hours: "8-10", projection: "strong", notes: %w[tobacco vanilla] }
    )
    pending_order = create_pending_order(status: :collecting_product)
    pending_order.conversation.update!(conversation_state: { "last_referenced_product" => product.name })
    message = pending_order.conversation.messages.create!(sender_type: :customer, content: "longevity kemon")
    interpretation = AiIntentClassifier::Result.new(
      intent: "product_details", secondary_intents: [], confidence: 0.95,
      entities: {}.with_indifferent_access, language: "banglish", sentiment: "neutral",
      needs_clarification: false, possible_intents: []
    )

    reply = BotReplyGenerator.new(
      pending_order: pending_order,
      customer_message: message,
      outcome: :product_details_requested,
      interpretation: interpretation
    ).content

    assert_includes reply, "The Club-er"
    assert_includes reply, "8-10 hours-er moto longevity"
    assert_includes reply, "strong projection"
    assert_not_includes reply, "available products"
  end

  test "formats product details concisely without presenting combined stock as variant stock" do
    product = create_product(
      name: "The Club", stock_quantity: 0, short_description: "Warm tobacco and vanilla.",
      product_attributes: {
        scent_families: %w[warm sweet tobacco], notes: %w[spices citrus tobacco vanilla],
        occasions: %w[evening party], longevity_hours: "8-10", projection: "strong"
      }
    )
    product.product_variants.create!(name: "10 ML", size: "10 ML", price: 390, stock_quantity: 200)
    product.product_variants.create!(name: "30 ML", size: "30 ML", price: 850, stock_quantity: 100)
    pending_order = create_pending_order(status: :collecting_product)
    message = pending_order.conversation.messages.create!(
      sender_type: :customer, content: "notes of The Club?"
    )

    reply = BotReplyGenerator.new(
      pending_order: pending_order, customer_message: message, outcome: :product_details_requested
    ).content

    assert_includes reply, "Profile: warm, sweet, and tobacco."
    assert_includes reply, "Notes: spices, citrus, tobacco, and vanilla."
    assert_includes reply, "Sizes: 10 ML ৳390, 30 ML ৳850."
    assert_not_includes reply, "300 currently in stock"
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

  test "answers only the requested variant price without appending the catalog" do
    product = create_product(name: "The Office", stock_quantity: 0)
    product.product_variants.create!(name: "10 ML", size: "10 ML", price: 350, stock_quantity: 5)
    product.product_variants.create!(name: "30 ML", size: "30 ML", price: 850, stock_quantity: 5)
    pending_order = create_pending_order(status: :collecting_product)
    pending_order.conversation.update!(conversation_state: { "last_referenced_product" => product.name })
    message = pending_order.conversation.messages.create!(sender_type: :customer, content: "10ml price koto?")

    reply = BotReplyGenerator.new(pending_order: pending_order, customer_message: message,
      outcome: :price_inquiry).content

    assert_includes reply, "10 ML: ৳350"
    assert_not_includes reply, "30 ML"
    assert_not_includes reply, "Here are our available products"
  end

  test "answers weather questions from the current product profile" do
    product = create_product(name: "The Club", product_attributes: {
      scent_families: %w[tobacco warm sweet], occasions: %w[evening party]
    })
    pending_order = create_pending_order(status: :collecting_product)
    pending_order.conversation.update!(conversation_state: { "last_referenced_product" => product.name })
    message = pending_order.conversation.messages.create!(sender_type: :customer,
      content: "kon weather er jonno perfect eita?")
    interpretation = AiIntentClassifier::Result.new(intent: "product_details", secondary_intents: [], confidence: 0.95,
      entities: {}.with_indifferent_access, language: "banglish", sentiment: "neutral",
      needs_clarification: false, possible_intents: [])

    reply = BotReplyGenerator.new(pending_order: pending_order, customer_message: message,
      outcome: :product_weather_requested, interpretation: interpretation).content

    assert_includes reply, "cool weather, evening, ba AC environment-e best"
    assert_not_includes reply, "starts from"
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

  test "answers a return policy question without starting a return request" do
    pending_order = create_pending_order(status: :collecting_product)
    pending_order.conversation.business.create_business_policy!(return_policy: "Replacement is available within 7 days.")

    reply = BotReplyGenerator.new(
      pending_order: pending_order,
      outcome: :return_policy_requested
    ).content

    assert_includes reply, "Replacement is available within 7 days."
    assert_not_includes reply, "what happened"
    assert_not_includes reply, "order number"
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
