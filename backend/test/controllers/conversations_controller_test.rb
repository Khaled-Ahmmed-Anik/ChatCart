require "test_helper"

class ConversationsControllerTest < ActionDispatch::IntegrationTest
  test "lookup returns conversation messages and pending order" do
    product = Product.create!(
      name: "Fresh Musk",
      woo_commerce_product_id: "woo-123",
      price: 750,
      stock_quantity: 10,
      tags: "fresh,office,daily,musk"
    )
    conversation = Conversation.create!(
      channel: "facebook",
      external_customer_id: "fb-user-123",
      last_message_at: Time.current
    )
    customer_message = conversation.messages.create!(sender_type: :customer, content: "I want Fresh Musk")
    bot_message = conversation.messages.create!(sender_type: :bot, content: "How many bottles?")
    pending_order = conversation.create_pending_order!(
      product: product,
      quantity: 2,
      customer_name: "Khaled",
      phone: "+8801712345678",
      address: "Dhaka",
      status: :awaiting_confirmation
    )

    get conversations_lookup_url, params: {
      channel: "facebook",
      external_customer_id: "fb-user-123"
    }

    assert_response :success

    response_body = JSON.parse(response.body)
    assert_equal conversation.id, response_body["id"]
    assert_equal "facebook", response_body["channel"]
    assert_equal "fb-user-123", response_body["external_customer_id"]
    assert_equal "active", response_body["status"]
    assert_equal conversation.last_message_at.iso8601, response_body["last_message_at"]

    assert_equal [customer_message.id, bot_message.id], response_body["messages"].map { |message| message["id"] }
    assert_equal ["customer", "bot"], response_body["messages"].map { |message| message["sender_type"] }
    assert_equal ["I want Fresh Musk", "How many bottles?"], response_body["messages"].map { |message| message["content"] }

    serialized_pending_order = response_body["pending_order"]
    assert_equal pending_order.id, serialized_pending_order["id"]
    assert_equal "awaiting_confirmation", serialized_pending_order["status"]
    assert_equal 2, serialized_pending_order["quantity"]
    assert_equal "1500.0", serialized_pending_order["total_price"]
    assert_equal true, serialized_pending_order["ready_for_confirmation"]
    assert_equal "Khaled", serialized_pending_order["customer_name"]
    assert_equal "+8801712345678", serialized_pending_order["phone"]
    assert_equal "Dhaka", serialized_pending_order["address"]

    serialized_product = serialized_pending_order["product"]
    assert_equal product.id, serialized_product["id"]
    assert_equal "Fresh Musk", serialized_product["name"]
    assert_equal "woo-123", serialized_product["woo_commerce_product_id"]
    assert_equal "750.0", serialized_product["price"]
    assert_equal 10, serialized_product["stock_quantity"]
    assert_equal "fresh,office,daily,musk", serialized_product["tags"]
    assert_equal true, serialized_product["active"]
  end

  test "lookup returns nil pending order when conversation has none" do
    Conversation.create!(channel: "facebook", external_customer_id: "fb-user-123")

    get conversations_lookup_url, params: {
      channel: "facebook",
      external_customer_id: "fb-user-123"
    }

    assert_response :success

    response_body = JSON.parse(response.body)
    assert_nil response_body["pending_order"]
  end

  test "lookup returns not found for unknown conversation" do
    get conversations_lookup_url, params: {
      channel: "facebook",
      external_customer_id: "missing-user"
    }

    assert_response :not_found

    response_body = JSON.parse(response.body)
    assert_equal "Conversation not found", response_body["error"]
  end

  test "lookup requires channel and external customer id" do
    get conversations_lookup_url

    assert_response :unprocessable_entity

    response_body = JSON.parse(response.body)
    assert_equal ["can't be blank"], response_body.dig("errors", "channel")
    assert_equal ["can't be blank"], response_body.dig("errors", "external_customer_id")
  end
end
