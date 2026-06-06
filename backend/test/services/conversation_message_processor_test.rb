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

  test "does not collect quantity beyond stock" do
    product = create_product(stock_quantity: 1)
    pending_order = create_pending_order(product: product, status: :collecting_quantity)
    message = pending_order.conversation.messages.create!(sender_type: :customer, content: "2")

    ConversationMessageProcessor.new(message: message, pending_order: pending_order).process

    assert_nil pending_order.reload.quantity
    assert_predicate pending_order, :collecting_quantity?
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

  private

  def process_message(pending_order, content)
    message = pending_order.conversation.messages.create!(sender_type: :customer, content: content)
    ConversationMessageProcessor.new(message: message, pending_order: pending_order).process
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
