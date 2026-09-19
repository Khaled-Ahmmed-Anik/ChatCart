module Webhooks
  class MessengerController < ApplicationController
    CHANNEL = "facebook"
    DEFAULT_VERIFY_TOKEN = "local-messenger-verify-token"

    before_action :verify_webhook_signature, only: :create

    def show
      if valid_verification_request?
        render plain: params["hub.challenge"], status: :ok
      else
        render plain: "Forbidden", status: :forbidden
      end
    end

    def create
      event_results = messaging_events.map { |event| handle_messaging_event(event) }
      response_body = serialize_webhook_response(event_results)
      response_status = event_results.any? { |result| result[:status] == "processed" } ? :created : :ok

      render json: response_body, status: response_status
    rescue ActiveRecord::RecordInvalid => error
      render json: { errors: error.record.errors.to_hash(true) }, status: :unprocessable_entity
    end

    private

    def handle_messaging_event(event)
      event_type = MessengerEventClassifier.new(event).type

      if event_type == :customer_text
        process_messaging_event(event).merge(type: event_type, status: "processed")
      else
        { type: event_type, status: "ignored" }
      end
    end

    def process_messaging_event(event)
      sender_id = event.dig(:sender, :id)
      content = event.dig(:message, :text)
      result = CustomerMessageRecorder.new(
        channel: CHANNEL,
        external_customer_id: sender_id,
        content: content,
        metadata: event.to_unsafe_h
      ).record
      delivery = MessengerReplySender.new(
        recipient_id: sender_id,
        content: result.bot_reply.content
      ).deliver

      {
        recipient_id: sender_id,
        bot_reply: {
          content: result.bot_reply.content
        },
        delivery: serialize_delivery(delivery),
        conversation: serialize_conversation(result.conversation),
        pending_order: serialize_pending_order(result.pending_order)
      }
    end

    def serialize_webhook_response(event_results)
      return event_results.first if event_results.one?

      {
        processed: event_results.count { |result| result[:status] == "processed" },
        ignored: event_results.count { |result| result[:status] == "ignored" },
        events: event_results
      }
    end

    def verify_webhook_signature
      app_secret = ENV["MESSENGER_APP_SECRET"]
      signature = request.headers["X-Hub-Signature-256"]
      signature_match = signature&.match(/\Asha256=([0-9a-f]{64})\z/i)

      return head :forbidden if app_secret.blank? || signature_match.nil?

      expected_signature = OpenSSL::HMAC.hexdigest("SHA256", app_secret, request.raw_post)
      return if ActiveSupport::SecurityUtils.secure_compare(expected_signature, signature_match[1].downcase)

      head :forbidden
    end

    def valid_verification_request?
      params["hub.mode"] == "subscribe" &&
        params["hub.verify_token"] == verify_token &&
        params["hub.challenge"].present?
    end

    def verify_token
      ENV.fetch("MESSENGER_VERIFY_TOKEN", DEFAULT_VERIFY_TOKEN)
    end

    def messaging_events
      params.fetch(:entry, []).flat_map { |entry| entry.fetch(:messaging, []) }
    end

    def serialize_conversation(conversation)
      {
        id: conversation.id,
        channel: conversation.channel,
        external_customer_id: conversation.external_customer_id,
        status: conversation.status,
        last_message_at: conversation.last_message_at&.iso8601
      }
    end

    def serialize_pending_order(pending_order)
      {
        id: pending_order.id,
        status: pending_order.status,
        product_id: pending_order.product_id,
        quantity: pending_order.quantity,
        total_price: pending_order.total_price.to_s,
        ready_for_confirmation: pending_order.ready_for_confirmation?
      }
    end

    def serialize_delivery(delivery)
      {
        delivered: delivery.delivered,
        skipped: delivery.skipped,
        status: delivery.status,
        error: delivery.error
      }
    end
  end
end
