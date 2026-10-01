require "test_helper"

module Webhooks
  class WhatsappControllerTest < ActionDispatch::IntegrationTest
    include ActiveJob::TestHelper

    APP_SECRET = "test-whatsapp-app-secret"

    setup do
      @previous_secret = ENV["WHATSAPP_APP_SECRET"]
      @previous_token = ENV["WHATSAPP_VERIFY_TOKEN"]
      ENV["WHATSAPP_APP_SECRET"] = APP_SECRET
      ENV["WHATSAPP_VERIFY_TOKEN"] = "test-whatsapp-verify-token"
    end

    teardown do
      ENV["WHATSAPP_APP_SECRET"] = @previous_secret
      ENV["WHATSAPP_VERIFY_TOKEN"] = @previous_token
    end

    test "verifies the webhook subscription" do
      get webhooks_whatsapp_url, params: {
        "hub.mode": "subscribe",
        "hub.verify_token": "test-whatsapp-verify-token",
        "hub.challenge": "challenge-123"
      }

      assert_response :success
      assert_equal "challenge-123", response.body
    end

    test "rejects an invalid verification token" do
      get webhooks_whatsapp_url, params: {
        "hub.mode": "subscribe", "hub.verify_token": "wrong", "hub.challenge": "challenge-123"
      }

      assert_response :forbidden
    end

    test "records text messages and immediately enqueues background processing" do
      assert_difference -> { WhatsappWebhookEvent.count }, 1 do
        assert_enqueued_with(job: ProcessWhatsappEventJob) { post_signed_payload(message_payload) }
      end

      assert_response :ok
      event = WhatsappWebhookEvent.find_by!(external_event_id: "wamid.inbound-1")
      assert_equal "customer_text", event.event_type
      assert_equal "8801712345678", event.sender_id
      assert_equal "phone-number-1", event.phone_number_id
      assert_equal "Hello", event.payload.dig("text", "body")
    end

    test "resolves the business using its WhatsApp phone number connection" do
      business = Business.create!(name: "WhatsApp Shop", slug: "whatsapp-shop")
      business.channel_connections.create!(
        channel: "whatsapp", external_account_id: "phone-number-1", status: "active", access_token: "secret"
      )

      post_signed_payload(message_payload)

      assert_equal business, WhatsappWebhookEvent.find_by!(external_event_id: "wamid.inbound-1").business
    end

    test "does not route messages through a disconnected WhatsApp connection" do
      business = Business.create!(name: "Disconnected Shop", slug: "disconnected-shop")
      business.channel_connections.create!(
        channel: "whatsapp", external_account_id: "phone-number-1", status: "disconnected", access_token: "secret"
      )

      post_signed_payload(message_payload)

      assert_equal Business.default, WhatsappWebhookEvent.find_by!(external_event_id: "wamid.inbound-1").business
    end

    test "records statuses without scheduling customer processing" do
      payload = base_payload(
        statuses: [ { id: "wamid.outbound-1", status: "delivered", timestamp: "1789900000", recipient_id: "8801712345678" } ]
      )

      assert_no_enqueued_jobs only: ProcessWhatsappEventJob do
        post_signed_payload(payload)
      end

      event = WhatsappWebhookEvent.last
      assert_response :ok
      assert_equal "delivery_status", event.event_type
      assert_equal "ignored", event.status
    end

    test "updates an outbound delivery from a delivery status webhook" do
      inbound_event = WhatsappWebhookEvent.create!(
        business: Business.default,
        external_event_id: "wamid.inbound-for-status",
        event_type: "customer_text",
        sender_id: "8801712345678",
        phone_number_id: "phone-number-1",
        payload: { "text" => { "body" => "Hello" } }
      )
      conversation = Conversation.create!(
        business: Business.default, channel: "whatsapp", external_customer_id: "8801712345678"
      )
      message = conversation.messages.create!(sender_type: "bot", content: "Hello back")
      delivery = WhatsappDelivery.create!(
        whatsapp_webhook_event: inbound_event,
        message: message,
        recipient_id: "8801712345678",
        phone_number_id: "phone-number-1",
        external_message_id: "wamid.outbound-1",
        status: "pending"
      )
      payload = base_payload(
        statuses: [ { id: "wamid.outbound-1", status: "read", timestamp: "1789900000", recipient_id: "8801712345678" } ]
      )

      post_signed_payload(payload)

      assert_response :ok
      assert_equal "read", delivery.reload.status
      assert_not_nil delivery.delivered_at
    end

    test "does not enqueue duplicate WhatsApp message IDs" do
      assert_enqueued_jobs 1, only: ProcessWhatsappEventJob do
        post_signed_payload(message_payload)
        post_signed_payload(message_payload)
      end

      assert_equal 1, WhatsappWebhookEvent.where(external_event_id: "wamid.inbound-1").count
      assert_equal 1, JSON.parse(response.body).fetch("duplicates")
    end

    test "acknowledges but does not record or enqueue events for an inactive business" do
      business = Business.create!(name: "Suspended Shop", slug: "suspended-shop", status: "suspended")
      business.channel_connections.create!(
        channel: "whatsapp", external_account_id: "phone-number-1", status: "active", access_token: "secret"
      )

      assert_no_difference -> { WhatsappWebhookEvent.count } do
        assert_no_enqueued_jobs only: ProcessWhatsappEventJob do
          post_signed_payload(message_payload)
        end
      end

      assert_response :ok
      body = JSON.parse(response.body)
      assert_equal 0, body.fetch("accepted")
      assert_equal 1, body.fetch("ignored")
      assert_equal "ignored", body.fetch("events").first.fetch("status")
    end

    test "rejects missing and invalid signatures" do
      post webhooks_whatsapp_url,
        params: message_payload.to_json,
        headers: { "Content-Type" => "application/json" }
      assert_response :forbidden

      post webhooks_whatsapp_url,
        params: message_payload.to_json,
        headers: { "Content-Type" => "application/json", "X-Hub-Signature-256" => "sha256=#{'0' * 64}" }
      assert_response :forbidden
      assert_equal 0, WhatsappWebhookEvent.count
    end

    private

    def post_signed_payload(payload)
      raw = payload.to_json
      signature = OpenSSL::HMAC.hexdigest("SHA256", APP_SECRET, raw)
      post webhooks_whatsapp_url,
        params: raw,
        headers: { "Content-Type" => "application/json", "X-Hub-Signature-256" => "sha256=#{signature}" }
    end

    def message_payload
      base_payload(messages: [ {
        from: "8801712345678", id: "wamid.inbound-1", timestamp: "1789900000",
        type: "text", text: { body: "Hello" }
      } ])
    end

    def base_payload(messages: nil, statuses: nil)
      value = { messaging_product: "whatsapp", metadata: { phone_number_id: "phone-number-1" } }
      value[:messages] = messages if messages
      value[:statuses] = statuses if statuses
      {
        object: "whatsapp_business_account",
        entry: [ { id: "waba-1", changes: [ { field: "messages", value: value } ] } ]
      }
    end
  end
end
