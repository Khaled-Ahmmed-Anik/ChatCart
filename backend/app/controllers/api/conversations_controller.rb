module Api
  class ConversationsController < BaseController
    REVIEW_LABELS = %w[successful abandoned confusing needs_follow_up incorrect_reply].freeze
    FEEDBACK_RATINGS = %w[helpful unhelpful].freeze

    before_action -> { require_roles!(:owner, :admin, :sales_agent) }, only: %i[handover resume reply review feedback]
    before_action :set_conversation, only: %i[show handover resume reply review feedback]

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
      ConversationHandoverSummary.new(conversation: @conversation, reason: "seller_takeover").generate!
      render json: summary(@conversation)
    end

    def resume
      return if performed?

      update_handover_timing!("resolved_at")
      @conversation.active!
      render json: summary(@conversation)
    end

    def reply
      return if performed?

      return render json: { error: "Conversation must be handed over" }, status: :unprocessable_entity unless @conversation.handed_over?

      message = @conversation.messages.create!(sender_type: :seller, content: params.require(:content))
      update_handover_timing!("first_seller_response_at")
      enqueue_messenger_reply(message) if @conversation.channel == "facebook"
      render json: message, status: :created
    end

    def review
      label = params.require(:label)
      return render json: { error: "Invalid review label" }, status: :unprocessable_entity unless label.in?(REVIEW_LABELS)
      return unless record_intent_correction

      update_conversation_state!("quality_review", {
        "label" => label,
        "notes" => params[:notes].to_s.strip.presence,
        "reviewed_at" => Time.current.iso8601,
        "reviewer_id" => current_user.id
      }.compact)
      render json: summary(@conversation)
    end

    def feedback
      rating = params.require(:rating)
      return render json: { error: "Invalid feedback rating" }, status: :unprocessable_entity unless rating.in?(FEEDBACK_RATINGS)

      update_conversation_state!("customer_feedback", {
        "rating" => rating,
        "recorded_at" => Time.current.iso8601,
        "source" => params[:source].presence || "dashboard"
      })
      render json: summary(@conversation)
    end

    private

    def record_intent_correction
      corrected_intent = params[:corrected_intent].presence
      return true if corrected_intent.blank?
      unless ConversationIntentRegistry.valid?(corrected_intent)
        render json: { error: "Invalid corrected intent" }, status: :unprocessable_entity
        return false
      end

      message = @conversation.messages.customer.find_by(id: params[:message_id])
      unless message
        render json: { error: "Customer message not found" }, status: :unprocessable_entity
        return false
      end

      ConversationClassificationFeedback.new(message: message).record_correction!(
        corrected_intent: corrected_intent,
        reviewer_id: current_user.id
      )
      true
    end

    def update_handover_timing!(field)
      state = @conversation.conversation_state.to_h
      summary = state["handover_summary"].to_h
      return if summary.blank? || summary[field].present?

      timestamp = Time.current.iso8601
      summary[field] = timestamp
      history = Array(state["handover_history"])
      history[-1] = summary if history.any?
      @conversation.update!(conversation_state: state.merge("handover_summary" => summary, "handover_history" => history))
    end

    def set_conversation
      @conversation = current_business.conversations.find(params[:id])
    end

    def summary(conversation)
      handover = conversation.conversation_state.to_h["handover_summary"]
      quality = ConversationQualityEvaluator.new(conversation: conversation).call
      {
        id: conversation.id,
        channel: conversation.channel,
        external_customer_id: conversation.external_customer_id,
        status: conversation.status,
        last_message_at: conversation.last_message_at,
        message_count: conversation.messages.size,
        needs_attention: conversation.handed_over?,
        handover_reason: handover&.dig("reason"),
        handover_started_at: handover&.dig("created_at"),
        handover_summary: handover,
        quality: quality
      }
    end

    def update_conversation_state!(key, value)
      state = @conversation.conversation_state.to_h.merge(key => value)
      @conversation.update!(conversation_state: state)
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
