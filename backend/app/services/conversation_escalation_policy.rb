class ConversationEscalationPolicy
  REPEATED_PROBLEM_THRESHOLD = 3

  def initialize(conversation:, interpretation:, outcome:)
    @conversation = conversation
    @interpretation = interpretation
    @outcome = outcome.to_sym
  end

  def handover?
    explicit_human_request? || repeated_problem?
  end

  def reason
    return "customer_requested_human" if explicit_human_request?
    return "repeated_complaint" if problem_count("complaint") >= REPEATED_PROBLEM_THRESHOLD
    return "repeated_confusion" if clarification_count >= REPEATED_PROBLEM_THRESHOLD

    nil
  end

  private

  attr_reader :conversation, :interpretation, :outcome

  def explicit_human_request?
    interpretation&.intents&.include?("human_agent") || outcome == :human_agent
  end

  def repeated_problem?
    problem_count("complaint") >= REPEATED_PROBLEM_THRESHOLD ||
      clarification_count >= REPEATED_PROBLEM_THRESHOLD
  end

  def intelligence
    conversation.messages.customer.order(id: :desc).limit(8).filter_map do |message|
      message.metadata.to_h["conversation_intelligence"]
    end
  end

  def problem_count(intent)
    intelligence.count { |item| item["intent"] == intent }
  end

  def clarification_count
    intelligence.count { |item| item["needs_clarification"] || item["outcome"] == "clarification_needed" }
  end
end
