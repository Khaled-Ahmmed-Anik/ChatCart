require "test_helper"

class CustomerMessageRecorderTest < ActiveSupport::TestCase
  test "records customer message, processes pending order, and creates bot reply" do
    product = Product.create!(name: "Fresh Musk", price: 750, stock_quantity: 10)

    result = CustomerMessageRecorder.new(
      channel: "facebook",
      external_customer_id: "fb-user-123",
      content: "I want Fresh Musk",
      metadata: { "source" => "messenger" }
    ).record

    assert_equal "facebook", result.conversation.channel
    assert_equal "fb-user-123", result.conversation.external_customer_id
    assert_equal "I want Fresh Musk", result.message.content
    assert_equal({ "source" => "messenger" }, result.message.metadata)
    assert_equal product, result.pending_order.product
    assert_predicate result.pending_order, :collecting_quantity?
    assert_equal "Nice choice! Fresh Musk is ৳750 per bottle. How many would you like?", result.bot_reply.content
    assert_equal :product_selected, result.outcome
  end

  test "starts a new order when a returning customer selects a product" do
    previous_product = Product.create!(name: "Fresh Musk", price: 750, stock_quantity: 10)
    new_product = Product.create!(name: "Royal Oud", price: 1200, stock_quantity: 5)
    conversation = Conversation.create!(channel: "facebook", external_customer_id: "fb-user-123")
    previous_order = conversation.create_pending_order!(
      product: previous_product,
      quantity: 2,
      customer_name: "Khaled",
      phone: "01712345678",
      address: "Dhaka",
      status: :confirmed
    )

    assert_difference -> { conversation.pending_orders.count }, 1 do
      result = record_message("I want Royal Oud")

      assert_not_equal previous_order, result.pending_order
      assert_equal new_product, result.pending_order.product
      assert_predicate result.pending_order, :collecting_quantity?
      assert_equal :product_selected, result.outcome
    end

    assert_predicate previous_order.reload, :confirmed?
    assert_equal 2, previous_order.quantity
  end

  test "starts a blank order when a returning customer asks for a new order" do
    conversation = Conversation.create!(channel: "facebook", external_customer_id: "fb-user-123")
    previous_order = conversation.create_pending_order!(status: :cancelled)

    result = nil
    assert_difference -> { conversation.pending_orders.count }, 1 do
      result = record_message("new order")
    end

    assert_not_equal previous_order, result.pending_order
    assert_predicate result.pending_order, :collecting_product?
    assert_equal :restarted, result.outcome
    assert_includes result.bot_reply.content, "start a fresh order"
    assert_predicate previous_order.reload, :cancelled?
  end

  test "starts a new order from a Banglish request with punctuation" do
    conversation = Conversation.create!(channel: "facebook", external_customer_id: "fb-user-123")
    previous_order = conversation.create_pending_order!(status: :confirmed)

    result = nil
    assert_difference -> { conversation.pending_orders.count }, 1 do
      result = record_message("noton order kora jabe?")
    end

    assert_not_equal previous_order, result.pending_order
    assert_predicate result.pending_order, :collecting_product?
    assert_equal :restarted, result.outcome
    assert_includes result.bot_reply.content, "start a fresh order"
  end

  test "does not create a new order for a conversational follow-up" do
    conversation = Conversation.create!(channel: "facebook", external_customer_id: "fb-user-123")
    previous_order = conversation.create_pending_order!(status: :confirmed)

    assert_no_difference -> { conversation.pending_orders.count } do
      result = record_message("Thank you")

      assert_equal previous_order, result.pending_order
      assert_equal :thanks, result.outcome
    end
  end

  test "reopens the latest confirmed order when the customer changes it" do
    product = Product.create!(name: "Fresh Musk", price: 750, stock_quantity: 10)
    conversation = Conversation.create!(channel: "facebook", external_customer_id: "fb-user-123")
    order = conversation.create_pending_order!(
      product: product,
      quantity: 2,
      customer_name: "Khaled",
      phone: "01712345678",
      address: "Dhaka",
      status: :confirmed
    )

    assert_no_difference -> { conversation.pending_orders.count } do
      result = record_message("change quantity to 3")

      assert_equal order, result.pending_order
      assert_equal :confirmed_order_updated, result.outcome
      assert_includes result.bot_reply.content, "reopened it for review"
      assert_includes result.bot_reply.content, "3 × Fresh Musk"
    end

    assert_predicate order.reload, :awaiting_confirmation?
    assert_equal 3, order.quantity
  end

  test "acknowledges deferred confirmation without repeating the order summary" do
    product = Product.create!(name: "Fresh Musk", price: 750, stock_quantity: 10)
    conversation = Conversation.create!(channel: "facebook", external_customer_id: "fb-user-123")
    conversation.create_pending_order!(
      product: product,
      quantity: 2,
      customer_name: "Khaled",
      phone: "01712345678",
      address: "Dhaka",
      status: :awaiting_confirmation
    )

    result = record_message("I will confirm later")

    assert_equal :confirmation_deferred, result.outcome
    assert_includes result.bot_reply.content, "isn’t confirmed yet"
    assert_not_includes result.bot_reply.content, "order summary"
  end

  test "returns confirmed order details in response to a Banglish request" do
    product = Product.create!(name: "Fresh Musk", price: 750, stock_quantity: 10)
    conversation = Conversation.create!(channel: "facebook", external_customer_id: "fb-user-123")
    order = conversation.create_pending_order!(
      product: product,
      quantity: 2,
      customer_name: "Khaled",
      phone: "01712345678",
      address: "Dhaka",
      status: :confirmed
    )

    assert_no_difference -> { conversation.pending_orders.count } do
      result = record_message("amar order details ta ki silo?")

      assert_equal order, result.pending_order
      assert_equal :order_details_requested, result.outcome
      assert_includes result.bot_reply.content, "confirmed order details"
      assert_includes result.bot_reply.content, "2 × Fresh Musk"
      assert_includes result.bot_reply.content, "৳1500"
    end
  end

  private

  def record_message(content)
    CustomerMessageRecorder.new(
      channel: "facebook",
      external_customer_id: "fb-user-123",
      content: content
    ).record
  end
end
