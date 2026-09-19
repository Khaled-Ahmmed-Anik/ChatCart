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
end
