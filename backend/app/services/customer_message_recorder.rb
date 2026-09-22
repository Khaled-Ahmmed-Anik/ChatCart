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
      if conversation.handed_over?
        outcome = :awaiting_human
        next
      end
      current_order = conversation.pending_order
      interpretation = classify_intent(message, current_order, conversation)
      record_intelligence(message, interpretation)
      pending_order = pending_order_for(conversation, interpretation)
      processor = ConversationMessageProcessor.new(
        message: message,
        pending_order: pending_order,
        interpretation: interpretation
      )
      processor.process
      outcome = processor.outcome
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
      ConversationMemory.new(conversation).remember!(
        interpretation: interpretation,
        pending_order: pending_order,
        outcome: outcome
      )
      log_decision(conversation, message, interpretation, outcome, processor.secondary_outcomes)
      bot_reply = conversation.messages.create!(
        sender_type: :bot,
        content: final_reply_content(message, pending_order, outcome, interpretation, response_plan)
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

  def final_reply_content(message, pending_order, outcome, interpretation, response_plan)
    return response_plan.content if interpretation.blank?
    return response_plan.content if message.metadata["intent_classifier"] == "local"

    AiConversationAssistant.new(
      customer_message: message,
      pending_order: pending_order,
      outcome: outcome,
      language: response_plan.language,
      tone: response_plan.tone,
      address_preference: response_plan.address_preference
    ).rewrite(fallback: response_plan.content)
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
    if local.interpretation.present?
      message.update!(metadata: message.metadata.merge("intent_classifier" => "local"))
      return local.interpretation
    end

    AiIntentClassifier.new(
      message: message,
      pending_order: pending_order,
      recent_messages: conversation.messages.order(created_at: :desc, id: :desc).limit(10).reverse
    ).classify
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
