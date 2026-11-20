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
    text.match?(Constants::Conversation::BROWSING_ONLY) || purchase_declined?
  end

  def purchase_declined?
    final_clause = text.split(/\b(?:but|instead|kintu|borong)\b/).last.to_s
    final_clause.match?(Constants::Conversation::PURCHASE_DECLINED)
  end

  def comparison?
    text.match?(/\b(compare|comparison|difference|versus|vs|better)\b/)
  end

  def price?
    text.match?(ConversationActionPlanner::INFORMATIONAL_PATTERNS[:price_inquiry]) || text.include?("how much")
  end

  def variants?
    text.match?(/\b(size|sizes|variant|variants)\b.*\b(option|options|available|have|ache|ki|what|which)\b/) ||
      text.match?(/\b(what|which|available|ki ki)\b.*\b(size|sizes|variant|variants)\b/) ||
      text.match?(/\A(size|sizes|size options|variant|variants)\z/)
  end

  private

  attr_reader :text
end
