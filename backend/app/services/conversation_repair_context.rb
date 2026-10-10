class ConversationRepairContext
  def initialize(conversation:, message: nil)
    @conversation = conversation
    @message = message
  end

  def support_follow_up?
    previous_outcome == "unsupported_support_requested" &&
      message&.content.to_s.match?(Constants::Conversation::SUPPORT_FAILURE_FOLLOW_UP)
  end

  def repeated?
    previous_outcome.in?(%w[product_not_found clarification_needed])
  end

  def topic
    texts = [ message&.content ].compact
    texts.concat(previous_messages.limit(3).pluck(:content)) if message&.content.to_s.match?(Constants::Conversation::REPAIR_REFERENCE)
    texts.each do |text|
      match = Constants::Conversation::REPAIR_TOPICS.find { |_topic, pattern| text.match?(pattern) }
      return match.first if match
    end
    :product
  end

  private

  attr_reader :conversation, :message

  def previous_messages
    scope = conversation.messages.customer.order(id: :desc)
    message ? scope.where("id < ?", message.id) : scope
  end

  def previous_outcome
    previous_messages.first&.metadata.to_h.dig("conversation_intelligence", "outcome")
  end
end
