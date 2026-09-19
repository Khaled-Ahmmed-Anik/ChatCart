module Api
  class ConversationsController < BaseController
    before_action -> { require_roles!(:owner, :admin, :sales_agent) }, only: %i[handover resume reply]
    before_action :set_conversation, only: %i[show handover resume reply]

    def index
      conversations = current_business.conversations.includes(:messages).order(last_message_at: :desc)
      conversations = conversations.where(status: params[:status]) if params[:status].present?
      render json: conversations.map { |conversation| summary(conversation) }
    end

    def show
      render json: summary(@conversation).merge(
        messages: @conversation.messages.order(:created_at, :id).as_json(
          only: %i[id sender_type content metadata created_at]
        )
      )
    end

    def handover
      return if performed?

      @conversation.handed_over!
      render json: summary(@conversation)
    end

    def resume
      return if performed?

      @conversation.active!
      render json: summary(@conversation)
    end

    def reply
      return if performed?

      return render json: { error: "Conversation must be handed over" }, status: :unprocessable_entity unless @conversation.handed_over?

      message = @conversation.messages.create!(sender_type: :seller, content: params.require(:content))
      enqueue_messenger_reply(message) if @conversation.channel == "facebook"
      render json: message, status: :created
    end

    private

    def set_conversation
      @conversation = current_business.conversations.find(params[:id])
    end

    def summary(conversation)
      {
        id: conversation.id,
        channel: conversation.channel,
        external_customer_id: conversation.external_customer_id,
        status: conversation.status,
        last_message_at: conversation.last_message_at,
        message_count: conversation.messages.size
      }
    end

    def enqueue_messenger_reply(message)
      event = current_business.messenger_webhook_events.create!(
        event_type: "postback", sender_id: @conversation.external_customer_id,
        payload: { source: "seller_dashboard" }, status: "processed", processed_at: Time.current
      )
      delivery = MessengerDelivery.create!(
        messenger_webhook_event: event, message: message, recipient_id: @conversation.external_customer_id
      )
      SendMessengerReplyJob.perform_later(delivery)
    end
  end
end
