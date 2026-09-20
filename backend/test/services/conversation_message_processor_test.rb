require "test_helper"

class ConversationMessageProcessorTest < ActiveSupport::TestCase
  test "collects product by matching active in-stock product name" do
    product = create_product(name: "Fresh Musk")
    pending_order = create_pending_order(status: :collecting_product)
    message = pending_order.conversation.messages.create!(
      sender_type: :customer,
      content: "I want Fresh Musk please"
    )

    ConversationMessageProcessor.new(message: message, pending_order: pending_order).process

    assert_equal product, pending_order.reload.product
    assert_predicate pending_order, :collecting_quantity?
  end

  test "collects a product variant before quantity and uses variant stock" do
    product = create_product(name: "The Oud", stock_quantity: 0)
    product.product_variants.create!(name: "3 ml", size: "3 ml", price: 250, stock_quantity: 2)
    product.product_variants.create!(name: "6 ml", size: "6 ml", price: 450, stock_quantity: 5)
    pending_order = create_pending_order(status: :collecting_product)

    process_message(pending_order, "I want The Oud")
    assert_predicate pending_order.reload, :collecting_variant?

    processor = process_message(pending_order, "6 ml")
    assert_equal :variant_selected, processor.outcome
    assert_equal "6 ml", pending_order.reload.product_variant.size
    assert_predicate pending_order, :collecting_quantity?

    unavailable = process_message(pending_order, "6")
    assert_equal :quantity_unavailable, unavailable.outcome
    assert_predicate pending_order.reload, :collecting_quantity?
    assert_equal 5, pending_order.product_variant.stock_quantity
  end

  test "does not collect inactive or out of stock product" do
    create_product(name: "Fresh Musk", active: false, stock_quantity: 10)
    create_product(name: "Royal Oud", active: true, stock_quantity: 0)
    pending_order = create_pending_order(status: :collecting_product)
    message = pending_order.conversation.messages.create!(
      sender_type: :customer,
      content: "I want Fresh Musk or Royal Oud"
    )

    ConversationMessageProcessor.new(message: message, pending_order: pending_order).process

    assert_nil pending_order.reload.product
    assert_predicate pending_order, :collecting_product?
  end

  test "collects quantity when stock is available" do
    product = create_product(stock_quantity: 3)
    pending_order = create_pending_order(product: product, status: :collecting_quantity)
    message = pending_order.conversation.messages.create!(sender_type: :customer, content: "2")

    ConversationMessageProcessor.new(message: message, pending_order: pending_order).process

    assert_equal 2, pending_order.reload.quantity
    assert_predicate pending_order, :collecting_name?
  end

  test "collects a naturally written quantity" do
    product = create_product(stock_quantity: 5)
    pending_order = create_pending_order(product: product, status: :collecting_quantity)

    processor = process_message(pending_order, "I would like two bottles please")

    assert_equal 2, pending_order.reload.quantity
    assert_predicate pending_order, :collecting_name?
    assert_equal :quantity_collected, processor.outcome
  end

  test "does not collect quantity beyond stock" do
    product = create_product(stock_quantity: 1)
    pending_order = create_pending_order(product: product, status: :collecting_quantity)
    message = pending_order.conversation.messages.create!(sender_type: :customer, content: "2")

    ConversationMessageProcessor.new(message: message, pending_order: pending_order).process

    assert_nil pending_order.reload.quantity
    assert_predicate pending_order, :collecting_quantity?
  end

  test "explains invalid and unavailable quantities through outcomes" do
    product = create_product(stock_quantity: 2)
    pending_order = create_pending_order(product: product, status: :collecting_quantity)

    assert_equal :invalid_quantity, process_message(pending_order, "a few").outcome
    assert_equal :quantity_unavailable, process_message(pending_order, "5").outcome
    assert_nil pending_order.reload.quantity
  end

  test "answers conversational intents without advancing the order" do
    pending_order = create_pending_order(status: :collecting_product)

    assert_equal :greeting, process_message(pending_order, "Hello!").outcome
    assert_equal :help, process_message(pending_order, "Can you help me?").outcome
    assert_equal :thanks, process_message(pending_order, "Thank you").outcome
    assert_equal :price_inquiry, process_message(pending_order, "What is the price of Fresh Musk?").outcome
    assert_equal :stock_inquiry, process_message(pending_order, "Is Fresh Musk available?").outcome
    assert_predicate pending_order.reload, :collecting_product?
  end

  test "collects name, phone, and address then awaits confirmation" do
    pending_order = create_pending_order(
      product: create_product,
      quantity: 1,
      status: :collecting_name
    )

    process_message(pending_order, "Khaled Ahmed")
    assert_equal "Khaled Ahmed", pending_order.reload.customer_name
    assert_predicate pending_order, :collecting_phone?

    process_message(pending_order, "+8801712345678")
    assert_equal "+8801712345678", pending_order.reload.phone
    assert_predicate pending_order, :collecting_address?

    process_message(pending_order, "House 10, Road 2, Dhaka")
    assert_equal "House 10, Road 2, Dhaka", pending_order.reload.address
    assert_predicate pending_order, :awaiting_confirmation?
    assert pending_order.ready_for_confirmation?
  end

  test "ignores non-customer messages" do
    pending_order = create_pending_order(status: :collecting_product)
    message = pending_order.conversation.messages.create!(sender_type: :bot, content: "Fresh Musk")

    ConversationMessageProcessor.new(message: message, pending_order: pending_order).process

    assert_nil pending_order.reload.product
  end

  test "confirms an order awaiting confirmation" do
    pending_order = create_ready_pending_order(status: :awaiting_confirmation)

    process_message(pending_order, "confirm")

    assert_predicate pending_order.reload, :confirmed?
  end

  test "cancels an order awaiting confirmation" do
    pending_order = create_ready_pending_order(status: :awaiting_confirmation)

    process_message(pending_order, "cancel")

    assert_predicate pending_order.reload, :cancelled?
  end

  test "keeps awaiting confirmation for unclear confirmation reply" do
    pending_order = create_ready_pending_order(status: :awaiting_confirmation)

    process_message(pending_order, "maybe later")

    assert_predicate pending_order.reload, :awaiting_confirmation?
  end

  test "keeps the order pending when the customer will confirm later" do
    [ "I will confirm later", "will confirm letter", "pore confirm korbo", "ekhon na" ].each do |content|
      pending_order = create_ready_pending_order(status: :awaiting_confirmation)

      processor = process_message(pending_order, content)

      assert_equal :confirmation_deferred, processor.outcome, content
      assert_predicate pending_order.reload, :awaiting_confirmation?, content
    end
  end

  test "recognizes change the order while awaiting confirmation" do
    pending_order = create_ready_pending_order(status: :awaiting_confirmation)

    processor = process_message(pending_order, "change the order")

    assert_equal :order_change_requested, processor.outcome
    assert_predicate pending_order.reload, :awaiting_confirmation?
  end

  test "updates order details using natural correction commands" do
    pending_order = create_ready_pending_order(status: :awaiting_confirmation)

    processor = process_message(pending_order, "change quantity to 3")

    assert_equal :order_updated, processor.outcome
    assert_equal 3, pending_order.reload.quantity
    assert_predicate pending_order, :awaiting_confirmation?
    assert_equal "quantity", pending_order.change_history.sole.fetch("field")
    assert_equal "1", pending_order.change_history.sole.fetch("from")
    assert_equal "3", pending_order.change_history.sole.fetch("to")
    assert pending_order.change_history.sole.fetch("changed_at").present?
    assert pending_order.change_history.sole.fetch("message_id").present?
  end

  test "explains how to update a confirmed order" do
    pending_order = create_ready_pending_order(status: :confirmed)

    processor = process_message(pending_order, "change my previous order")

    assert_equal :order_change_requested, processor.outcome
    assert_predicate pending_order.reload, :confirmed?
    assert_empty pending_order.change_history
  end

  test "updates and reopens a confirmed order for confirmation" do
    pending_order = create_ready_pending_order(status: :confirmed)

    processor = process_message(pending_order, "change phone to 01812345678")

    pending_order.reload
    assert_equal :confirmed_order_updated, processor.outcome
    assert_equal "01812345678", pending_order.phone
    assert_predicate pending_order, :awaiting_confirmation?
    assert_equal(
      { "field" => "phone", "from" => "+8801712345678", "to" => "01812345678" },
      pending_order.change_history.sole.slice("field", "from", "to")
    )
  end

  test "does not update an order submitted to WooCommerce" do
    pending_order = create_ready_pending_order(status: :submitted_to_woocommerce)

    processor = process_message(pending_order, "change quantity to 3")

    assert_equal :submitted_order_change_requested, processor.outcome
    assert_equal 1, pending_order.reload.quantity
    assert_empty pending_order.change_history
  end

  test "does not update a cancelled order" do
    pending_order = create_ready_pending_order(status: :cancelled)

    processor = process_message(pending_order, "change address to Chattogram")

    assert_equal :cancelled_order_change_requested, processor.outcome
    assert_equal "Dhaka", pending_order.reload.address
    assert_empty pending_order.change_history
  end

  test "restarts an order without creating a new conversation" do
    pending_order = create_ready_pending_order(status: :awaiting_confirmation)

    processor = process_message(pending_order, "new order")

    pending_order.reload
    assert_equal :restarted, processor.outcome
    assert_predicate pending_order, :collecting_product?
    assert_nil pending_order.product
    assert_nil pending_order.quantity
    assert_nil pending_order.customer_name
  end

  test "collects multiple explicitly extracted details from one message" do
    product = create_product(name: "Fresh Musk", stock_quantity: 10)
    pending_order = create_pending_order(status: :collecting_product)
    message = pending_order.conversation.messages.create!(
      sender_type: :customer,
      content: "Fresh Musk 2 ta, name Khaled, phone 01712345678, address Dhaka"
    )
    interpretation = ai_interpretation(
      intent: "select_product",
      entities: {
        product_name: product.name,
        quantity: 2,
        customer_name: "Khaled",
        phone: "01712345678",
        address: "Dhaka"
      }
    )

    processor = ConversationMessageProcessor.new(
      message: message,
      pending_order: pending_order,
      interpretation: interpretation
    )
    processor.process

    pending_order.reload
    assert_equal :multiple_details_collected, processor.outcome
    assert_equal product, pending_order.product
    assert_equal 2, pending_order.quantity
    assert_equal "Khaled", pending_order.customer_name
    assert_equal "01712345678", pending_order.phone
    assert_equal "Dhaka", pending_order.address
    assert_predicate pending_order, :awaiting_confirmation?
  end

  test "routes a confident conversational AI intent without changing the order" do
    pending_order = create_ready_pending_order(status: :confirmed)
    message = pending_order.conversation.messages.create!(sender_type: :customer, content: "kemon asen?")
    processor = ConversationMessageProcessor.new(
      message: message,
      pending_order: pending_order,
      interpretation: ai_interpretation(intent: "wellbeing")
    )

    processor.process

    assert_equal :wellbeing, processor.outcome
    assert_predicate pending_order.reload, :confirmed?
  end

  test "asks for clarification when AI confidence is low" do
    pending_order = create_pending_order(status: :collecting_product)
    message = pending_order.conversation.messages.create!(sender_type: :customer, content: "oi ta den")
    processor = ConversationMessageProcessor.new(
      message: message,
      pending_order: pending_order,
      interpretation: ai_interpretation(intent: "select_product", confidence: 0.4, needs_clarification: true)
    )

    processor.process

    assert_equal :clarification_needed, processor.outcome
    assert_nil pending_order.reload.product
  end

  test "exposes informational secondary outcomes without executing another order action" do
    product = create_product(name: "Fresh Musk")
    pending_order = create_pending_order(status: :collecting_product)
    message = pending_order.conversation.messages.create!(
      sender_type: :customer, content: "Fresh Musk, delivery charge koto?"
    )
    interpretation = ai_interpretation(
      intent: "select_product",
      entities: { product_name: product.name },
      secondary_intents: %w[delivery_charge change_quantity]
    )
    processor = ConversationMessageProcessor.new(
      message: message, pending_order: pending_order, interpretation: interpretation
    )

    processor.process

    assert_equal :product_selected, processor.outcome
    assert_equal [ :delivery_charge_requested ], processor.secondary_outcomes
    assert_equal product, pending_order.reload.product
    assert_nil pending_order.quantity
  end

  test "reuses remembered customer details only when explicitly requested" do
    conversation = Conversation.create!(channel: "facebook", external_customer_id: SecureRandom.uuid)
    product = create_product
    conversation.create_pending_order!(
      product: product, quantity: 1, customer_name: "Khaled", phone: "01712345678",
      address: "Badda, Dhaka", status: :confirmed
    )
    current = conversation.create_pending_order!(product: product, quantity: 2, status: :collecting_name)

    process_message(current, "same name")
    process_message(current, "same phone")
    process_message(current, "same address")

    current.reload
    assert_equal "Khaled", current.customer_name
    assert_equal "01712345678", current.phone
    assert_equal "Badda, Dhaka", current.address
    assert_predicate current, :awaiting_confirmation?
  end

  private

  def process_message(pending_order, content)
    message = pending_order.conversation.messages.create!(sender_type: :customer, content: content)
    processor = ConversationMessageProcessor.new(message: message, pending_order: pending_order)
    processor.process
    processor
  end

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

  def create_ready_pending_order(attributes = {})
    create_pending_order(
      {
        product: create_product,
        quantity: 1,
        customer_name: "Khaled",
        phone: "+8801712345678",
        address: "Dhaka"
      }.merge(attributes)
    )
  end

  def ai_interpretation(intent:, entities: {}, confidence: 0.95, needs_clarification: false, possible_intents: [], secondary_intents: [])
    AiIntentClassifier::Result.new(
      intent: intent,
      secondary_intents: secondary_intents,
      confidence: confidence,
      entities: entities.with_indifferent_access,
      language: "banglish",
      sentiment: "neutral",
      needs_clarification: needs_clarification,
      possible_intents: possible_intents
    )
  end
end
