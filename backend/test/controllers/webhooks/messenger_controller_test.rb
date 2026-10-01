require "test_helper"

module Webhooks
  class MessengerControllerTest < ActionDispatch::IntegrationTest
    include ActiveJob::TestHelper

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
    end

    test "create records customer text, enqueues processing, and immediately returns ok" do
      payload = messenger_payload(sender_id: "fb-user-123", text: "I want Fresh Musk", message_id: "mid-123")

      assert_no_difference [ -> { Conversation.count }, -> { Message.count }, -> { PendingOrder.count } ] do
        assert_enqueued_with(job: ProcessMessengerEventJob) do
          post_signed_payload payload
        end
      end

      assert_response :ok
      event = MessengerWebhookEvent.find_by!(external_event_id: "mid-123")
      assert_equal "customer_text", event.event_type
      assert_equal "received", event.status
      assert_equal "fb-user-123", event.sender_id
      assert_equal({ "type" => "customer_text", "status" => "received" }, JSON.parse(response.body))
    end

    test "create records every event across entries and enqueues only customer text" do
      payload = {
        object: "page",
        entry: [
          {
            messaging: [
              messaging_event(sender_id: "fb-user-1", text: "Hello", message_id: "mid-1"),
              { delivery: { mids: [ "sent-1" ] } },
              { read: { watermark: 1_780_000_000_000 } }
            ]
          },
          {
            messaging: [
              messaging_event(sender_id: "fb-user-2", text: "Hi", message_id: "mid-2"),
              { sender: { id: "page-1" }, message: { mid: "echo-1", is_echo: true, text: "Reply" } },
              { sender: { id: "fb-user-2" }, message: { mid: "attachment-1", attachments: [ { type: "image" } ] } }
            ]
          }
        ]
      }

      assert_difference -> { MessengerWebhookEvent.count }, 6 do
        assert_enqueued_jobs 2, only: ProcessMessengerEventJob do
          post_signed_payload payload
        end
      end

      assert_response :ok
      body = JSON.parse(response.body)
      assert_equal 2, body.fetch("accepted")
      assert_equal 4, body.fetch("ignored")
      assert_equal 0, body.fetch("duplicates")
      assert_equal %w[customer_text delivery read customer_text message_echo attachment], body.fetch("events").pluck("type")
    end

    test "create does not enqueue or process a duplicate message ID" do
      payload = messenger_payload(sender_id: "fb-user-123", text: "Hello", message_id: "same-mid")

      assert_enqueued_jobs 1, only: ProcessMessengerEventJob do
        post_signed_payload payload
        assert_response :ok
        post_signed_payload payload
      end

      assert_response :ok
      assert_equal 1, MessengerWebhookEvent.where(external_event_id: "same-mid").count
      assert_equal "duplicate", JSON.parse(response.body).fetch("status")
    end

    test "create acknowledges unsupported and malformed events without jobs" do
      payload = {
        object: "page",
        entry: [
          {
            messaging: [
              { sender: {}, message: {} },
              { sender: { id: "fb-user-1" }, postback: { payload: "CONFIRM_ORDER" } },
              { sender: { id: "fb-user-1" }, reaction: { action: "react" } }
            ]
          }
        ]
      }

      assert_no_enqueued_jobs only: ProcessMessengerEventJob do
        post_signed_payload payload
      end

      assert_response :ok
      assert_equal %w[malformed_message postback unknown], MessengerWebhookEvent.order(:id).pluck(:event_type)
      assert MessengerWebhookEvent.all.all? { |event| event.status == "ignored" }
    end

    test "create acknowledges an empty payload" do
      post_signed_payload(object: "page", entry: [])

      assert_response :ok
      assert_equal({ "accepted" => 0, "ignored" => 0, "duplicates" => 0, "events" => [] }, JSON.parse(response.body))
    end

    test "create acknowledges but does not record or enqueue events for an inactive business" do
      business = Business.create!(name: "Disabled Shop", slug: "disabled-shop", status: "disabled")
      business.channel_connections.create!(
        channel: "facebook", external_account_id: "page-1", status: "active", access_token: "secret"
      )
      payload = messenger_payload(sender_id: "fb-user-123", text: "Hello", message_id: "mid-disabled")

      assert_no_difference -> { MessengerWebhookEvent.count } do
        assert_no_enqueued_jobs only: ProcessMessengerEventJob do
          post_signed_payload payload
        end
      end

      assert_response :ok
      assert_equal({ "type" => "customer_text", "status" => "ignored" }, JSON.parse(response.body))
    end

    test "create rejects a missing webhook signature without recording events" do
      post webhooks_messenger_url,
        params: messenger_payload(sender_id: "fb-user-123", text: "Hello", message_id: "mid-1").to_json,
        headers: { "Content-Type" => "application/json" }

      assert_response :forbidden
      assert_equal 0, MessengerWebhookEvent.count
    end

    test "create rejects an invalid webhook signature without recording events" do
      payload = messenger_payload(sender_id: "fb-user-123", text: "Hello", message_id: "mid-1").to_json

      post webhooks_messenger_url,
        params: payload,
        headers: {
          "Content-Type" => "application/json",
          "X-Hub-Signature-256" => "sha256=#{"0" * 64}"
        }

      assert_response :forbidden
      assert_equal 0, MessengerWebhookEvent.count
    end

    test "create rejects requests when the app secret is not configured" do
      ENV.delete("MESSENGER_APP_SECRET")

      post_signed_payload messenger_payload(sender_id: "fb-user-123", text: "Hello", message_id: "mid-1")

      assert_response :forbidden
      assert_equal 0, MessengerWebhookEvent.count
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

    def messenger_payload(sender_id:, text:, message_id:)
      {
        object: "page",
        entry: [ { id: "page-1", messaging: [ messaging_event(sender_id: sender_id, text: text, message_id: message_id) ] } ]
      }
    end

    def messaging_event(sender_id:, text:, message_id:)
      {
        sender: { id: sender_id },
        recipient: { id: "page-1" },
        timestamp: 1_780_000_000_000,
        message: { mid: message_id, text: text }
      }
    end
  end
end
