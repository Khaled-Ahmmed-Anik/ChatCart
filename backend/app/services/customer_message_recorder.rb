class CustomerMessageRecorder
  Result = Struct.new(
    :conversation, :message, :bot_reply, :pending_order, :outcome, :interpretation, :response_plan,
    keyword_init: true
  )

  def initialize(channel:, external_customer_id:, content:, metadata: {}, business: Business.default)
    @channel = channel
    @external_customer_id = external_customer_id
    @content = content
    @metadata = metadata
    @business = business
  end

  def record
    conversation = nil
    message = nil
    bot_reply = nil
    pending_order = nil
    outcome = nil
    interpretation = nil
    response_plan = nil

    Conversation.transaction do
      conversation = find_or_create_conversation
      conversation.update!(last_message_at: Time.current)
      message = conversation.messages.create!(
        sender_type: :customer,
        content: content,
        metadata: metadata
      )
      if feedback_rating.present?
        record_customer_feedback!(conversation, feedback_rating)
        outcome = :feedback_recorded
        bot_reply = conversation.messages.create!(
          sender_type: :bot,
          content: feedback_rating == "helpful" ? "Thank you—glad I could help! 😊" : "Thank you for telling us. We’ll use this to improve the experience.",
          metadata: { "conversation_engine_version" => Constants::Conversation::ENGINE_VERSION }
        )
        next
      end
      if conversation.handed_over?
        outcome = :awaiting_human
        next
      end
      current_order = conversation.pending_order
      interpretation = classify_intent(message, current_order, conversation)
      record_classification_feedback(message, interpretation)
      record_intelligence(message, interpretation)
      pending_order = pending_order_for(conversation, interpretation)
      processor = ConversationMessageProcessor.new(
        message: message,
        pending_order: pending_order,
        interpretation: interpretation
      )
      processor.process
      outcome = processor.outcome
      record_outcome(message, outcome)
      ConversationClassificationFeedback.new(message: message).record_outcome!(outcome)
      GuidedSalesConversation.new(conversation).sync!(outcome: outcome, pending_order: pending_order)
      escalation = ConversationEscalationPolicy.new(
        conversation: conversation,
        interpretation: interpretation,
        outcome: outcome
      )
      if escalation.handover?
        conversation.update!(status: :handed_over)
        outcome = :human_handover_started
        message.update!(metadata: message.metadata.merge("handover_reason" => escalation.reason))
        ConversationHandoverSummary.new(
          conversation: conversation,
          reason: escalation.reason
        ).generate!
      end
      if pending_order.confirmed? && pending_order.ready_for_confirmation?
        captured_order = OrderCaptureService.new(pending_order).capture
        enqueue_delivery(captured_order)
      end
      response_plan = ConversationResponsePlanner.new(
        conversation: conversation,
        pending_order: pending_order,
        customer_message: message,
        outcome: outcome,
        interpretation: interpretation,
        secondary_outcomes: processor.secondary_outcomes
      ).plan
      ConversationTurnManager.new(conversation).record_turn!(
        message: message,
        pending_order: pending_order,
        outcome: outcome,
        interpretation: interpretation,
        secondary_outcomes: processor.secondary_outcomes,
        interrupted: response_plan.interrupted
      )
      ConversationMemory.new(conversation).remember!(
        interpretation: interpretation,
        pending_order: pending_order,
        outcome: outcome
      )
      log_decision(conversation, message, interpretation, outcome, processor.secondary_outcomes)
      bot_reply = conversation.messages.create!(
        sender_type: :bot,
        content: final_reply_content(message, pending_order, outcome, interpretation, response_plan),
        metadata: bot_reply_metadata
      )
    end

    Result.new(
      conversation: conversation,
      message: message,
      bot_reply: bot_reply,
      pending_order: pending_order,
      outcome: outcome,
      interpretation: interpretation,
      response_plan: response_plan
    )
  end

  private

  attr_reader :channel, :external_customer_id, :content, :metadata, :business

  def feedback_rating
    normalized = content.to_s.downcase.squish
    return "helpful" if normalized.in?([ "helpful", "yes helpful", "ভালো ছিল", "help hoise" ])
    "unhelpful" if normalized.in?([ "not helpful", "unhelpful", "helpful na", "ভালো ছিল না" ])
  end

  def record_customer_feedback!(conversation, rating)
    state = conversation.conversation_state.to_h.merge("customer_feedback" => {
      "rating" => rating,
      "recorded_at" => Time.current.iso8601,
      "source" => "customer_message"
    })
    conversation.update!(conversation_state: state)
  end

  def final_reply_content(message, pending_order, outcome, interpretation, response_plan)
    return response_plan.content if interpretation.blank?
    if message.metadata["intent_classifier"] == "local" &&
        !ConversationAiRollout.enabled?(:naturalizer_all_turns, conversation: pending_order.conversation)
      return response_plan.content
    end

    assistant = AiConversationAssistant.new(
      customer_message: message,
      pending_order: pending_order,
      outcome: outcome,
      language: response_plan.language,
      tone: response_plan.tone,
      address_preference: response_plan.address_preference,
      response_plan: response_plan
    )
    content = assistant.rewrite(fallback: response_plan.content)
    @ai_reply_metadata = assistant.telemetry.compact
    content
  end

  def bot_reply_metadata
    metadata = { "conversation_engine_version" => Constants::Conversation::ENGINE_VERSION }
    metadata["ai_assistant"] = @ai_reply_metadata if @ai_reply_metadata.present?
    metadata
  end

  def find_or_create_conversation
    business.conversations.find_or_create_by!(
      channel: channel,
      external_customer_id: external_customer_id
    )
  end

  def pending_order_for(conversation, interpretation)
    current_order = conversation.pending_order
    return conversation.create_pending_order! if current_order.blank?
    if current_order.status.in?(%w[confirmed cancelled]) && starts_new_order?(interpretation)
      return conversation.create_pending_order!
    end

    current_order
  end

  def starts_new_order?(interpretation)
    return true if interpretation&.intent.in?(%w[new_order repeat_order]) && !interpretation.needs_clarification

    normalized_content = content.to_s.downcase.strip
    return true if ConversationIntentDetector.new(normalized_content).new_order?

    ProductResolutionService.new(business: business, query: normalized_content).resolve.matched?
  end

  def classify_intent(message, pending_order, conversation)
    local = CompactIntentClassifier.new(message: message, pending_order: pending_order).classify
    @local_classification_result = local
    if local.interpretation.present?
      message.update!(metadata: message.metadata.merge("intent_classifier" => "local"))
      return local.interpretation
    end

    interpretation = AiIntentClassifier.new(
      message: message,
      pending_order: pending_order,
      recent_messages: conversation.messages.order(created_at: :desc, id: :desc).limit(10).reverse
    ).classify
    message.update!(metadata: message.metadata.merge("intent_classifier" => "gemini")) if interpretation.present?
    interpretation
  end

  def record_classification_feedback(message, interpretation)
    classifier = message.metadata["intent_classifier"].presence || "fallback"
    ConversationClassificationFeedback.new(message: message).record_prediction!(
      classifier: classifier,
      interpretation: interpretation,
      local_result: @local_classification_result
    )
  end

  def enqueue_delivery(order)
    integration = business.delivery_integration
    return unless integration&.active?

    submission = order.delivery_submissions.find_or_create_by!(delivery_integration: integration)
    SubmitDeliveryJob.perform_later(submission) unless submission.status == "submitted"
  end

  def record_intelligence(message, interpretation)
    return if interpretation.blank?

    safe_decision = {
      "intent" => interpretation.intent,
      "secondary_intents" => interpretation.secondary_intents,
      "confidence" => interpretation.confidence,
      "language" => interpretation.language,
      "sentiment" => interpretation.sentiment,
      "needs_clarification" => interpretation.needs_clarification
    }
    message.update!(metadata: message.metadata.merge("conversation_intelligence" => safe_decision))
  end

  def record_outcome(message, outcome)
    intelligence = message.metadata.to_h["conversation_intelligence"].to_h.merge("outcome" => outcome.to_s)
    message.update!(metadata: message.metadata.merge("conversation_intelligence" => intelligence))
  end

  def log_decision(conversation, message, interpretation, outcome, secondary_outcomes)
    MessengerSafeLogger.info(
      "conversation_decision",
      conversation_id: conversation.id,
      message_id: message.id,
      intent: interpretation&.intent,
      secondary_intents: interpretation&.secondary_intents,
      confidence: interpretation&.confidence,
      outcome: outcome,
      secondary_outcomes: secondary_outcomes,
      handed_over: conversation.handed_over?
    )
  end
end
