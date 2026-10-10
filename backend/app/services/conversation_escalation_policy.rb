class ConversationEscalationPolicy
  REPEATED_PROBLEM_THRESHOLD = 3

  def initialize(conversation:, interpretation:, outcome:)
    @conversation = conversation
    @interpretation = interpretation
    @outcome = outcome.to_sym
  end

  def handover?
    explicit_human_request? || urgent_support_case? || repeated_problem?
  end

  def reason
    return "customer_requested_human" if explicit_human_request?
    return urgent_support_reason if urgent_support_case?
    return "repeated_complaint" if consecutive_problem_count("complaint") >= REPEATED_PROBLEM_THRESHOLD
    return "repeated_confusion" if consecutive_clarification_count >= REPEATED_PROBLEM_THRESHOLD
    return "unsupported_support" if consecutive_support_count >= Constants::Conversation::SUPPORT_REPAIR_THRESHOLD
    return "repeated_unresolved_request" if consecutive_unresolved_count >= Constants::Conversation::CONVERSATION_REPAIR_THRESHOLD

    nil
  end

  private

  attr_reader :conversation, :interpretation, :outcome

  def explicit_human_request?
    interpretation&.intents&.include?("human_agent") || outcome == :human_agent
  end

  def repeated_problem?
    consecutive_problem_count("complaint") >= REPEATED_PROBLEM_THRESHOLD ||
      consecutive_clarification_count >= REPEATED_PROBLEM_THRESHOLD ||
      consecutive_support_count >= Constants::Conversation::SUPPORT_REPAIR_THRESHOLD ||
      consecutive_unresolved_count >= Constants::Conversation::CONVERSATION_REPAIR_THRESHOLD
  end

  def intelligence
    conversation.messages.customer.order(id: :desc).limit(8).filter_map do |message|
      message.metadata.to_h["conversation_intelligence"]
    end
  end

  def consecutive_problem_count(intent)
    intelligence.take_while { |item| item["intent"] == intent }.size
  end

  def consecutive_clarification_count
    intelligence.take_while do |item|
      item["needs_clarification"] || item["outcome"] == "clarification_needed"
    end.size
  end

  def consecutive_unresolved_count
    intelligence.take_while do |item|
      item["outcome"] == "product_not_found"
    end.size
  end

  def consecutive_support_count
    intelligence.take_while { |item| item["outcome"] == "unsupported_support_requested" }.size
  end

  def urgent_support_case?
    urgent_support_reason.present?
  end

  def urgent_support_reason
    return "refund_or_replacement" if interpretation&.intents&.intersect?(%w[refund_request replacement_request]) ||
      outcome.in?(%i[refund_requested replacement_requested])
    return "processed_order_change" if outcome == :submitted_order_change_requested

    latest = conversation.messages.customer.order(id: :desc).pick(:content).to_s.downcase
    return "delivery_dispute" if latest.match?(
      /\b(delivered|delivery|parcel)\b.*\b(not received|did not receive|didn'?t receive|missing|lost|pai nai|painai)\b|ডেলিভারি.*পাইনি/
    )
    "damaged_or_wrong_product" if latest.match?(
      /\b(damaged|broken|leak(?:ed|ing)?|wrong product|incorrect item|vanga|noshto)\b|ভাঙা|নষ্ট|ভুল পণ্য/
    )
  end
end
