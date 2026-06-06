require "test_helper"

module Webhooks
  class MessengerControllerTest < ActionDispatch::IntegrationTest
    test "show verifies messenger webhook with matching token" do
      get webhooks_messenger_url, params: {
        "hub.mode": "subscribe",
        "hub.verify_token": "local-messenger-verify-token",
        "hub.challenge": "challenge-123"
      }

      assert_response :success
      assert_equal "challenge-123", response.body
    end

    test "show rejects messenger webhook with invalid token" do
      get webhooks_messenger_url, params: {
        "hub.mode": "subscribe",
        "hub.verify_token": "wrong-token",
        "hub.challenge": "challenge-123"
      }

      assert_response :forbidden
      assert_equal "Forbidden", response.body
    end

    test "show rejects messenger webhook without challenge" do
      get webhooks_messenger_url, params: {
        "hub.mode": "subscribe",
        "hub.verify_token": "local-messenger-verify-token"
      }

      assert_response :forbidden
      assert_equal "Forbidden", response.body
    end

    test "create records messenger text and returns bot reply" do
      Product.create!(name: "Fresh Musk", price: 750, stock_quantity: 10)

      assert_difference -> { Conversation.count }, 1 do
        assert_difference -> { Message.count }, 2 do
          assert_difference -> { PendingOrder.count }, 1 do
            post webhooks_messenger_url, params: messenger_payload(
              sender_id: "fb-user-123",
              text: "I want Fresh Musk"
            ), as: :json
          end
        end
      end

      assert_response :created

      response_body = JSON.parse(response.body)
      conversation = Conversation.find(response_body.dig("conversation", "id"))
      customer_message = conversation.messages.customer.sole
      bot_message = conversation.messages.bot.sole

      assert_equal "fb-user-123", response_body["recipient_id"]
      assert_equal "facebook", response_body.dig("conversation", "channel")
      assert_equal "fb-user-123", response_body.dig("conversation", "external_customer_id")
      assert_equal "collecting_quantity", response_body.dig("pending_order", "status")
      assert_equal "Great choice. How many bottles of Fresh Musk would you like?", response_body.dig("bot_reply", "content")
      assert_equal "I want Fresh Musk", customer_message.content
      assert_equal "fb-user-123", customer_message.metadata.dig("sender", "id")
      assert_equal response_body.dig("bot_reply", "content"), bot_message.content
    end

    test "create reuses the same conversation for the sender" do
      product = Product.create!(name: "Fresh Musk", price: 750, stock_quantity: 10)
      conversation = Conversation.create!(channel: "facebook", external_customer_id: "fb-user-123")
      conversation.create_pending_order!(product: product, status: :collecting_quantity)

      assert_no_difference -> { Conversation.count } do
        assert_difference -> { Message.count }, 2 do
          post webhooks_messenger_url, params: messenger_payload(
            sender_id: "fb-user-123",
            text: "2"
          ), as: :json
        end
      end

      assert_response :created

      response_body = JSON.parse(response.body)
      assert_equal conversation.id, response_body.dig("conversation", "id")
      assert_equal "collecting_name", response_body.dig("pending_order", "status")
      assert_equal 2, response_body.dig("pending_order", "quantity")
      assert_equal "Perfect. Please share your name for the order.", response_body.dig("bot_reply", "content")
    end

    test "create returns validation errors when sender or text is missing" do
      post webhooks_messenger_url, params: { entry: [{ messaging: [{ sender: {}, message: {} }] }] }, as: :json

      assert_response :unprocessable_entity

      response_body = JSON.parse(response.body)
      assert_equal ["can't be blank"], response_body.dig("errors", "sender_id")
      assert_equal ["can't be blank"], response_body.dig("errors", "content")
    end

    private

    def messenger_payload(sender_id:, text:)
      {
        object: "page",
        entry: [
          {
            id: "page-1",
            messaging: [
              {
                sender: { id: sender_id },
                recipient: { id: "page-1" },
                timestamp: 1_780_000_000_000,
                message: {
                  mid: SecureRandom.uuid,
                  text: text
                }
              }
            ]
          }
        ]
      }
    end
  end
end
