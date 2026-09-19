require "test_helper"

module Webhooks
  class MessengerControllerTest < ActionDispatch::IntegrationTest
    APP_SECRET = "test-messenger-app-secret"

    setup do
      @previous_app_secret = ENV["MESSENGER_APP_SECRET"]
      ENV["MESSENGER_APP_SECRET"] = APP_SECRET
    end

    teardown do
      ENV["MESSENGER_APP_SECRET"] = @previous_app_secret
    end

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
            post_signed_payload messenger_payload(
              sender_id: "fb-user-123",
              text: "I want Fresh Musk"
            )
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
      assert_equal false, response_body.dig("delivery", "delivered")
      assert_equal true, response_body.dig("delivery", "skipped")
      assert_equal "MESSENGER_PAGE_ACCESS_TOKEN is not configured", response_body.dig("delivery", "error")
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
          post_signed_payload messenger_payload(
            sender_id: "fb-user-123",
            text: "2"
          )
        end
      end

      assert_response :created

      response_body = JSON.parse(response.body)
      assert_equal conversation.id, response_body.dig("conversation", "id")
      assert_equal "collecting_name", response_body.dig("pending_order", "status")
      assert_equal 2, response_body.dig("pending_order", "quantity")
      assert_equal "Perfect. Please share your name for the order.", response_body.dig("bot_reply", "content")
      assert_equal true, response_body.dig("delivery", "skipped")
    end

    test "create processes every messaging event across every entry" do
      Product.create!(name: "Fresh Musk", price: 750, stock_quantity: 10)
      payload = {
        object: "page",
        entry: [
          {
            id: "page-1",
            messaging: [
              messaging_event(sender_id: "fb-user-1", text: "I want Fresh Musk"),
              messaging_event(sender_id: "fb-user-2", text: "I want Fresh Musk")
            ]
          },
          {
            id: "page-1",
            messaging: [
              messaging_event(sender_id: "fb-user-3", text: "I want Fresh Musk")
            ]
          }
        ]
      }

      assert_difference -> { Conversation.count }, 3 do
        assert_difference -> { Message.count }, 6 do
          assert_difference -> { PendingOrder.count }, 3 do
            post_signed_payload payload
          end
        end
      end

      assert_response :created

      response_body = JSON.parse(response.body)
      assert_equal 3, response_body.fetch("events").size
      assert_equal %w[fb-user-1 fb-user-2 fb-user-3], response_body.fetch("events").pluck("recipient_id")
      assert_equal 3, response_body.fetch("processed")
      assert_equal 0, response_body.fetch("ignored")
      assert_equal [ "collecting_quantity" ] * 3, response_body.fetch("events").map { |event| event.dig("pending_order", "status") }
    end

    test "create processes customer text and ignores unsupported events in the same batch" do
      payload = {
        object: "page",
        entry: [
          {
            id: "page-1",
            messaging: [
              messaging_event(sender_id: "fb-user-1", text: "Hello"),
              { sender: {}, message: {} },
              { delivery: { mids: [ "message-1" ] } },
              { read: { watermark: 1_780_000_000_000 } },
              { sender: { id: "page-1" }, message: { is_echo: true, text: "Our reply" } },
              { sender: { id: "fb-user-1" }, postback: { payload: "CONFIRM_ORDER" } },
              { sender: { id: "fb-user-1" }, message: { attachments: [ { type: "image" } ] } },
              { sender: { id: "fb-user-1" }, reaction: { action: "react" } }
            ]
          }
        ]
      }

      assert_difference -> { Conversation.count }, 1 do
        assert_difference -> { Message.count }, 2 do
          assert_difference -> { PendingOrder.count }, 1 do
            post_signed_payload payload
          end
        end
      end

      assert_response :created

      response_body = JSON.parse(response.body)
      assert_equal 1, response_body.fetch("processed")
      assert_equal 7, response_body.fetch("ignored")
      assert_equal %w[customer_text malformed_message delivery read message_echo postback attachment unknown],
        response_body.fetch("events").pluck("type")
      assert_equal [ "processed", *([ "ignored" ] * 7) ], response_body.fetch("events").pluck("status")
    end

    test "create acknowledges a malformed message without recording it" do
      assert_no_difference [ -> { Conversation.count }, -> { Message.count }, -> { PendingOrder.count } ] do
        post_signed_payload(entry: [ { messaging: [ { sender: {}, message: {} } ] } ])
      end

      assert_response :ok

      response_body = JSON.parse(response.body)
      assert_equal "malformed_message", response_body.fetch("type")
      assert_equal "ignored", response_body.fetch("status")
    end

    test "create acknowledges an empty payload" do
      assert_no_difference [ -> { Conversation.count }, -> { Message.count }, -> { PendingOrder.count } ] do
        post_signed_payload(object: "page", entry: [])
      end

      assert_response :ok

      response_body = JSON.parse(response.body)
      assert_equal 0, response_body.fetch("processed")
      assert_equal 0, response_body.fetch("ignored")
      assert_empty response_body.fetch("events")
    end

    test "create acknowledges a delivery receipt" do
      assert_no_difference [ -> { Conversation.count }, -> { Message.count }, -> { PendingOrder.count } ] do
        post_signed_payload(
          object: "page",
          entry: [ { messaging: [ { delivery: { mids: [ "message-1" ] } } ] } ]
        )
      end

      assert_response :ok

      response_body = JSON.parse(response.body)
      assert_equal "delivery", response_body.fetch("type")
      assert_equal "ignored", response_body.fetch("status")
    end

    test "create acknowledges a message echo without recording it" do
      assert_no_difference [ -> { Conversation.count }, -> { Message.count }, -> { PendingOrder.count } ] do
        post_signed_payload(
          object: "page",
          entry: [
            {
              messaging: [
                { sender: { id: "page-1" }, message: { is_echo: true, text: "Our reply" } }
              ]
            }
          ]
        )
      end

      assert_response :ok

      response_body = JSON.parse(response.body)
      assert_equal "message_echo", response_body.fetch("type")
      assert_equal "ignored", response_body.fetch("status")
    end

    test "create acknowledges an attachment without recording it" do
      assert_no_difference [ -> { Conversation.count }, -> { Message.count }, -> { PendingOrder.count } ] do
        post_signed_payload(
          object: "page",
          entry: [
            {
              messaging: [
                {
                  sender: { id: "fb-user-1" },
                  message: { attachments: [ { type: "image" } ] }
                }
              ]
            }
          ]
        )
      end

      assert_response :ok

      response_body = JSON.parse(response.body)
      assert_equal "attachment", response_body.fetch("type")
      assert_equal "ignored", response_body.fetch("status")
    end

    test "create rejects a missing webhook signature" do
      post webhooks_messenger_url,
        params: messenger_payload(sender_id: "fb-user-123", text: "Hello").to_json,
        headers: { "Content-Type" => "application/json" }

      assert_response :forbidden
      assert_equal 0, Message.count
    end

    test "create rejects an invalid webhook signature" do
      payload = messenger_payload(sender_id: "fb-user-123", text: "Hello").to_json

      post webhooks_messenger_url,
        params: payload,
        headers: {
          "Content-Type" => "application/json",
          "X-Hub-Signature-256" => "sha256=#{"0" * 64}"
        }

      assert_response :forbidden
      assert_equal 0, Message.count
    end

    test "create rejects requests when the app secret is not configured" do
      ENV.delete("MESSENGER_APP_SECRET")

      post_signed_payload messenger_payload(sender_id: "fb-user-123", text: "Hello")

      assert_response :forbidden
      assert_equal 0, Message.count
    end

    private

    def post_signed_payload(payload)
      raw_payload = payload.to_json
      signature = OpenSSL::HMAC.hexdigest("SHA256", APP_SECRET, raw_payload)

      post webhooks_messenger_url,
        params: raw_payload,
        headers: {
          "Content-Type" => "application/json",
          "X-Hub-Signature-256" => "sha256=#{signature}"
        }
    end

    def messenger_payload(sender_id:, text:)
      {
        object: "page",
        entry: [
          {
            id: "page-1",
            messaging: [
              messaging_event(sender_id: sender_id, text: text)
            ]
          }
        ]
      }
    end

    def messaging_event(sender_id:, text:)
      {
        sender: { id: sender_id },
        recipient: { id: "page-1" },
        timestamp: 1_780_000_000_000,
        message: {
          mid: SecureRandom.uuid,
          text: text
        }
      }
    end
  end
end
