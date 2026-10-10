require "test_helper"

class ConversationMessagesControllerTest < ActionDispatch::IntegrationTest
  setup { Business.default.update!(category: "perfume") }
  test "create records an incoming customer message for a new conversation" do
    assert_difference -> { Conversation.count }, 1 do
      assert_difference -> { Message.count }, 2 do
        assert_difference -> { PendingOrder.count }, 1 do
          post conversation_messages_url, params: {
            conversation_message: {
              channel: "facebook",
              external_customer_id: "fb-user-123",
              content: "Hi, I want a perfume"
            }
          }, as: :json
        end
      end
    end

    assert_response :created

    response_body = JSON.parse(response.body)
    conversation = Conversation.find(response_body.dig("conversation", "id"))
    message = conversation.messages.customer.sole
    bot_reply = conversation.messages.bot.sole
    pending_order = conversation.pending_order

    assert_equal "facebook", response_body.dig("conversation", "channel")
    assert_equal "fb-user-123", response_body.dig("conversation", "external_customer_id")
    assert_equal "active", response_body.dig("conversation", "status")
    assert_equal conversation.last_message_at.iso8601, response_body.dig("conversation", "last_message_at")
    assert_equal message.id, response_body.dig("message", "id")
    assert_equal "customer", response_body.dig("message", "sender_type")
    assert_equal "Hi, I want a perfume", response_body.dig("message", "content")
    assert_equal bot_reply.id, response_body.dig("bot_reply", "id")
    assert_equal "bot", response_body.dig("bot_reply", "sender_type")
    assert_includes response_body.dig("bot_reply", "content"), "one perfume or a combo"
    assert_equal pending_order.id, response_body.dig("pending_order", "id")
    assert_equal "collecting_product", response_body.dig("pending_order", "status")
    assert_equal false, response_body.dig("pending_order", "ready_for_confirmation")
  end

  test "create reuses existing conversation and pending order" do
    conversation = Conversation.create!(
      channel: "facebook",
      external_customer_id: "fb-user-123",
      last_message_at: 1.day.ago
    )
    pending_order = conversation.create_pending_order!(status: :collecting_quantity)

    assert_no_difference -> { Conversation.count } do
      assert_no_difference -> { PendingOrder.count } do
        assert_difference -> { Message.count }, 2 do
          post conversation_messages_url, params: {
            conversation_message: {
              channel: "facebook",
              external_customer_id: "fb-user-123",
              content: "I want Fresh Musk"
            }
          }, as: :json
        end
      end
    end

    assert_response :created
    response_body = JSON.parse(response.body)

    assert_equal conversation.id, response_body.dig("conversation", "id")
    assert_equal pending_order.id, response_body.dig("pending_order", "id")
    assert_equal "collecting_quantity", response_body.dig("pending_order", "status")
    assert_equal "I want Fresh Musk", conversation.messages.customer.order(:created_at).last.content
    assert conversation.reload.last_message_at > 1.minute.ago
  end

  test "create processes product selection from incoming message" do
    product = Product.create!(name: "Fresh Musk", price: 750, stock_quantity: 10)

    post conversation_messages_url, params: {
      conversation_message: {
        channel: "facebook",
        external_customer_id: "fb-user-123",
        content: "I want Fresh Musk"
      }
    }, as: :json

    assert_response :created

    response_body = JSON.parse(response.body)
    assert_equal "collecting_quantity", response_body.dig("pending_order", "status")
    assert_equal product.id, response_body.dig("pending_order", "product_id")
    assert_equal "0", response_body.dig("pending_order", "total_price")
    assert_equal "Nice choice! Fresh Musk is ৳750 each. How many would you like?", response_body.dig("bot_reply", "content")
  end

  test "create processes quantity from incoming message" do
    conversation = Conversation.create!(channel: "facebook", external_customer_id: "fb-user-123")
    product = Product.create!(name: "Fresh Musk", price: 750, stock_quantity: 10)
    conversation.create_pending_order!(product: product, status: :collecting_quantity)

    post conversation_messages_url, params: {
      conversation_message: {
        channel: "facebook",
        external_customer_id: "fb-user-123",
        content: "2"
      }
    }, as: :json

    assert_response :created

    response_body = JSON.parse(response.body)
    assert_equal "collecting_name", response_body.dig("pending_order", "status")
    assert_equal 2, response_body.dig("pending_order", "quantity")
    assert_equal "1500.0", response_body.dig("pending_order", "total_price")
    assert_equal "Perfect—2 bottles. What name should I put on the order?", response_body.dig("bot_reply", "content")
  end

  test "create returns confirmation reply after address is collected" do
    conversation = Conversation.create!(channel: "facebook", external_customer_id: "fb-user-123")
    product = Product.create!(name: "Fresh Musk", price: 750, stock_quantity: 10)
    conversation.create_pending_order!(
      product: product,
      quantity: 2,
      customer_name: "Khaled",
      phone: "+8801712345678",
      status: :collecting_address
    )

    post conversation_messages_url, params: {
      conversation_message: {
        channel: "facebook",
        external_customer_id: "fb-user-123",
        content: "Dhaka"
      }
    }, as: :json

    assert_response :created

    response_body = JSON.parse(response.body)
    assert_equal "awaiting_confirmation", response_body.dig("pending_order", "status")
    assert_equal true, response_body.dig("pending_order", "ready_for_confirmation")
    assert_includes response_body.dig("bot_reply", "content"), "Here’s your order summary:"
    assert_includes response_body.dig("bot_reply", "content"), "2 × Fresh Musk"
    assert_includes response_body.dig("bot_reply", "content"), "Reply “confirm” to place it or “cancel” to stop."
  end

  test "create confirms an order awaiting confirmation" do
    conversation = Conversation.create!(channel: "facebook", external_customer_id: "fb-user-123")
    product = Product.create!(name: "Fresh Musk", price: 750, stock_quantity: 10)
    conversation.create_pending_order!(
      product: product,
      quantity: 2,
      customer_name: "Khaled",
      phone: "+8801712345678",
      address: "Dhaka",
      status: :awaiting_confirmation
    )

    post conversation_messages_url, params: {
      conversation_message: {
        channel: "facebook",
        external_customer_id: "fb-user-123",
        content: "confirm"
      }
    }, as: :json

    assert_response :created

    response_body = JSON.parse(response.body)
    assert_equal "confirmed", response_body.dig("pending_order", "status")
    assert_equal "Thanks! Your order is confirmed ✅ We’ll send it for processing shortly. Was this chat helpful? Reply “helpful” or “not helpful”.",
      response_body.dig("bot_reply", "content")
  end

  test "create cancels an order awaiting confirmation" do
    conversation = Conversation.create!(channel: "facebook", external_customer_id: "fb-user-123")
    product = Product.create!(name: "Fresh Musk", price: 750, stock_quantity: 10)
    conversation.create_pending_order!(
      product: product,
      quantity: 2,
      customer_name: "Khaled",
      phone: "+8801712345678",
      address: "Dhaka",
      status: :awaiting_confirmation
    )

    post conversation_messages_url, params: {
      conversation_message: {
        channel: "facebook",
        external_customer_id: "fb-user-123",
        content: "cancel"
      }
    }, as: :json

    assert_response :created

    response_body = JSON.parse(response.body)
    assert_equal "cancelled", response_body.dig("pending_order", "status")
    assert_equal "Your order has been cancelled. If you change your mind, just send “new order”.", response_body.dig("bot_reply", "content")
  end

  test "create returns validation errors for missing content" do
    assert_no_difference -> { Message.count } do
      post conversation_messages_url, params: {
        conversation_message: {
          channel: "facebook",
          external_customer_id: "fb-user-123",
          content: nil
        }
      }, as: :json
    end

    assert_response :unprocessable_entity

    response_body = JSON.parse(response.body)
    assert_equal [ "Content can't be blank" ], response_body.dig("errors", "content")
  end
end
