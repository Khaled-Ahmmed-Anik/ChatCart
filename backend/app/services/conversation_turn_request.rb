class ConversationTurnRequest
  def initialize(text)
    @text = ConversationTextNormalizer.call(text)
  end

  def information_only?
    question = text.match?(Constants::Conversation::PRODUCT_FACT_QUESTION)
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
