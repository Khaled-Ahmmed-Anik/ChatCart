module Webhooks
  class WhatsappController < ApplicationController
    before_action :verify_webhook_signature, only: :create

    def show
      if valid_verification_request?
        render plain: params["hub.challenge"], status: :ok
      else
        render plain: "Forbidden", status: :forbidden
      end
    end

    def create
      results = webhook_items.map { |item| record_item(item) }
      render json: serialize_response(results), status: :ok
    rescue ActiveRecord::RecordInvalid => error
      render json: { errors: error.record.errors.to_hash(true) }, status: :unprocessable_entity
    end

    private

    def verify_webhook_signature
      return if MetaWebhookSignatureVerifier.valid?(
        payload: request.raw_post,
        signature: request.headers["X-Hub-Signature-256"],
        app_secret: ENV["WHATSAPP_APP_SECRET"].presence || ENV["MESSENGER_APP_SECRET"]
      )

      head :forbidden
    end

    def valid_verification_request?
      params["hub.mode"] == "subscribe" &&
        params["hub.verify_token"] == verify_token &&
        params["hub.challenge"].present?
    end

    def verify_token
      ENV["WHATSAPP_VERIFY_TOKEN"].presence || ENV.fetch("MESSENGER_VERIFY_TOKEN", "local-whatsapp-verify-token")
    end

    def webhook_items
      params.fetch(:entry, []).flat_map do |entry|
        entry.fetch(:changes, []).flat_map { |change| items_from_value(change.fetch(:value, {})) }
      end
    end

    def items_from_value(value)
      phone_number_id = value.dig(:metadata, :phone_number_id).to_s
      messages = value.fetch(:messages, []).map do |message|
        {
          payload: message.to_unsafe_h,
          event_type: message[:type] == "text" && message.dig(:text, :body).present? ? :customer_text : :attachment,
          external_event_id: message[:id].to_s,
          sender_id: message[:from].to_s,
          phone_number_id: phone_number_id
        }
      end
      statuses = value.fetch(:statuses, []).map do |status|
        status_hash = status.to_unsafe_h
        {
          payload: status_hash,
          event_type: :delivery_status,
          external_event_id: [ "status", status[:id], status[:status], status[:timestamp] ].join("-"),
          sender_id: status[:recipient_id].to_s,
          phone_number_id: phone_number_id
        }
      end
      messages + statuses
    end

    def record_item(item)
      business = ChannelConnection.active.find_by(
        channel: "whatsapp", external_account_id: item.fetch(:phone_number_id)
      )&.business || Business.default
      return { type: item.fetch(:event_type), status: "ignored" } unless business.active?

      result = WhatsappWebhookEventRecorder.new(**item, business: business).record
      if result.created && result.event.event_type == "customer_text"
        ProcessWhatsappEventJob.set(wait: message_debounce).perform_later(result.event)
      elsif result.created && result.event.event_type == "delivery_status"
        update_delivery_status(result.event.payload)
      end
      { type: result.event.event_type, status: result.created ? result.event.status : "duplicate" }
    end

    def update_delivery_status(payload)
      delivery = WhatsappDelivery.find_by(external_message_id: payload["id"])
      return if delivery.blank?

      case payload["status"]
      when "sent"
        delivery.update!(status: "sent", last_error: nil)
      when "delivered", "read"
        delivery.update!(
          status: payload["status"], delivered_at: delivery.delivered_at || Time.current, last_error: nil
        )
      when "failed"
        error = Array(payload["errors"]).filter_map { |item| item["title"] || item["message"] }.join(", ")
        delivery.update!(status: "failed", last_error: error.presence || "WhatsApp reported delivery failure")
      end
    end

    def message_debounce
      ENV.fetch("WHATSAPP_MESSAGE_DEBOUNCE_SECONDS", "2").to_f.seconds
    end

    def serialize_response(results)
      {
        accepted: results.count { |result| result[:status] == "received" },
        ignored: results.count { |result| result[:status] == "ignored" },
        duplicates: results.count { |result| result[:status] == "duplicate" },
        events: results
      }
    end
  end
end
