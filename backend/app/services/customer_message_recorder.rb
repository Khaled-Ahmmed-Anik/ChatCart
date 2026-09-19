class CustomerMessageRecorder
  Result = Struct.new(:conversation, :message, :bot_reply, :pending_order, :outcome, :interpretation, keyword_init: true)

  def initialize(channel:, external_customer_id:, content:, metadata: {})
    @channel = channel
    @external_customer_id = external_customer_id
    @content = content
    @metadata = metadata
  end

  def record
    conversation = nil
    message = nil
    bot_reply = nil
    pending_order = nil
    outcome = nil
    interpretation = nil

    Conversation.transaction do
      conversation = find_or_create_conversation
      conversation.update!(last_message_at: Time.current)
      message = conversation.messages.create!(
        sender_type: :customer,
        content: content,
        metadata: metadata
      )
      current_order = conversation.pending_order
      interpretation = classify_intent(message, current_order, conversation)
      pending_order = pending_order_for(conversation, interpretation)
      processor = ConversationMessageProcessor.new(
        message: message,
        pending_order: pending_order,
        interpretation: interpretation
      )
      processor.process
      outcome = processor.outcome
      fallback_reply = BotReplyGenerator.new(
        pending_order: pending_order,
        customer_message: message,
        outcome: outcome,
        interpretation: interpretation
      ).content
      bot_reply = conversation.messages.create!(
        sender_type: :bot,
        content: AiConversationAssistant.new(
          customer_message: message,
          pending_order: pending_order,
          outcome: outcome
        ).rewrite(fallback: fallback_reply)
      )
    end

    Result.new(
      conversation: conversation,
      message: message,
      bot_reply: bot_reply,
      pending_order: pending_order,
      outcome: outcome,
      interpretation: interpretation
    )
  end

  private

  attr_reader :channel, :external_customer_id, :content, :metadata

  def find_or_create_conversation
    Conversation.find_or_create_by!(
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

    Product.find_each.any? { |product| normalized_content.include?(product.name.downcase) }
  end

  def classify_intent(message, pending_order, conversation)
    AiIntentClassifier.new(
      message: message,
      pending_order: pending_order,
      recent_messages: conversation.messages.order(created_at: :desc, id: :desc).limit(6).reverse
    ).classify
  end
end
