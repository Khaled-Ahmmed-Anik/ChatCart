module Webhooks
  class MessengerController < ApplicationController
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
      event_results = messaging_events.map { |entry_id, event| record_messaging_event(entry_id, event) }

      render json: serialize_webhook_response(event_results), status: :ok
    rescue ActiveRecord::RecordInvalid => error
      render json: { errors: error.record.errors.to_hash(true) }, status: :unprocessable_entity
    end

    private

    def record_messaging_event(entry_id, event)
      event_type = MessengerEventClassifier.new(event).type
      business = ChannelConnection.find_by(channel: "facebook", external_account_id: entry_id)&.business || Business.default
      result = MessengerWebhookEventRecorder.new(payload: event, event_type: event_type, business: business).record

      if result.created && event_type == :customer_text
        ProcessMessengerEventJob.set(wait: messenger_message_debounce).perform_later(result.event)
      end
      log_received(result.event, result.created)

      { type: event_type, status: result.created ? result.event.status : "duplicate" }
    end

    def serialize_webhook_response(event_results)
      return event_results.first if event_results.one?

      {
        accepted: event_results.count { |result| result[:status] == "received" },
        ignored: event_results.count { |result| result[:status] == "ignored" },
        duplicates: event_results.count { |result| result[:status] == "duplicate" },
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

    def messenger_message_debounce
      ENV.fetch("MESSENGER_MESSAGE_DEBOUNCE_SECONDS", "2").to_f.seconds
    end

    def messaging_events
      params.fetch(:entry, []).flat_map do |entry|
        entry.fetch(:messaging, []).map { |event| [ entry[:id].to_s, event ] }
      end
    end

    def log_received(event, created)
      MessengerSafeLogger.info(
        created ? "received" : "duplicate",
        messenger_message_id: event.external_event_id,
        sender_id: event.sender_id,
        event_type: event.event_type
      )
    end
  end
end
