module Webhooks
  class MessengerController < ApplicationController
    CHANNEL = "facebook"
    DEFAULT_VERIFY_TOKEN = "local-messenger-verify-token"

    def show
      if valid_verification_request?
        render plain: params["hub.challenge"], status: :ok
      else
        render plain: "Forbidden", status: :forbidden
      end
    end

    def create
      event = first_messaging_event
      sender_id = event.dig(:sender, :id)
      content = event.dig(:message, :text)

      if sender_id.blank? || content.blank?
        return render json: {
          errors: {
            sender_id: ["can't be blank"],
            content: ["can't be blank"]
          }
        }, status: :unprocessable_entity
      end

      result = CustomerMessageRecorder.new(
        channel: CHANNEL,
        external_customer_id: sender_id,
        content: content,
        metadata: event.to_unsafe_h
      ).record

      render json: {
        recipient_id: sender_id,
        bot_reply: {
          content: result.bot_reply.content
        },
        conversation: serialize_conversation(result.conversation),
        pending_order: serialize_pending_order(result.pending_order)
      }, status: :created
    rescue ActiveRecord::RecordInvalid => error
      render json: { errors: error.record.errors.to_hash(true) }, status: :unprocessable_entity
    end

    private

    def valid_verification_request?
      params["hub.mode"] == "subscribe" &&
        params["hub.verify_token"] == verify_token &&
        params["hub.challenge"].present?
    end

    def verify_token
      ENV.fetch("MESSENGER_VERIFY_TOKEN", DEFAULT_VERIFY_TOKEN)
    end

    def first_messaging_event
      params.fetch(:entry, []).first&.fetch(:messaging, [])&.first || {}
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
  end
end
