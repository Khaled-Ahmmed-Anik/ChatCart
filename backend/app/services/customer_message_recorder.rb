class CustomerMessageRecorder
  Result = Struct.new(:conversation, :message, :bot_reply, :pending_order, :outcome, keyword_init: true)

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

    Conversation.transaction do
      conversation = find_or_create_conversation
      conversation.update!(last_message_at: Time.current)
      message = conversation.messages.create!(
        sender_type: :customer,
        content: content,
        metadata: metadata
      )
      pending_order = pending_order_for(conversation)
      processor = ConversationMessageProcessor.new(message: message, pending_order: pending_order)
      processor.process
      outcome = processor.outcome
      fallback_reply = BotReplyGenerator.new(
        pending_order: pending_order,
        customer_message: message,
        outcome: outcome
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
      outcome: outcome
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

  def pending_order_for(conversation)
    current_order = conversation.pending_order
    return conversation.create_pending_order! if current_order.blank?
    return conversation.create_pending_order! if current_order.status.in?(%w[confirmed cancelled]) && starts_new_order?

    current_order
  end

  def starts_new_order?
    normalized_content = content.to_s.downcase.strip
    return true if ConversationIntentDetector.new(normalized_content).new_order?

    Product.find_each.any? { |product| normalized_content.include?(product.name.downcase) }
  end
end
