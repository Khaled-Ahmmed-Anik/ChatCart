class ConversationTurnRequest
  def initialize(text)
    @question_mark = text.to_s.include?("?")
    @text = ConversationTextNormalizer.call(text)
  end

  def information_only?
    question = text.match?(Constants::Conversation::PRODUCT_FACT_QUESTION) ||
      @question_mark && Constants::Catalogue::QUESTION_TOPICS.values.any? { |topic| text.match?(topic.fetch(:question)) }
    return false unless question

    !text.match?(Constants::Conversation::EXPLICIT_PURCHASE_ACTION) &&
      !text.match?(Constants::Conversation::EXPLICIT_QUANTITY_UNITS)
  end

  def browsing_only?
    text.match?(Constants::Conversation::BROWSING_ONLY)
  end

  private

  attr_reader :text
end
