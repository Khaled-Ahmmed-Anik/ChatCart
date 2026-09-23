class ConversationQualityEvaluator
  SCORE_FLOOR = 0
  SCORE_CEILING = 100

  def initialize(conversation:)
    @conversation = conversation
  end

  def call
    customer_messages = conversation.messages.customer.order(:created_at, :id).to_a
    bot_messages = conversation.messages.bot.order(:created_at, :id).to_a
    metrics = build_metrics(customer_messages, bot_messages)
    flags = quality_flags(metrics)

    {
      score: score(metrics),
      grade: grade(score(metrics)),
      outcome: conversation_outcome,
      flags: flags,
      metrics: metrics,
      review: conversation.conversation_state.to_h["quality_review"],
      customer_feedback: conversation.conversation_state.to_h["customer_feedback"],
      engine_versions: bot_messages.filter_map { |message| message.metadata.to_h["conversation_engine_version"] }.uniq
    }
  end

  private

  attr_reader :conversation

  def build_metrics(customer_messages, bot_messages)
    intelligence = customer_messages.map { |message| message.metadata.to_h["conversation_intelligence"].to_h }
    bot_replies = bot_messages.map { |message| normalize(message.content) }
    {
      customer_turns: customer_messages.count,
      bot_turns: bot_messages.count,
      clarification_turns: intelligence.count { |item| item["needs_clarification"] || item["outcome"] == "clarification_needed" },
      negative_turns: intelligence.count { |item| item["sentiment"] == "negative" },
      repeated_bot_replies: bot_replies.tally.values.sum { |count| [ count - 1, 0 ].max },
      handovers: handover_entries.count,
      currently_waiting_for_seller: conversation.handed_over?,
      order_confirmed: successful_order?
    }
  end

  def quality_flags(metrics)
    flags = []
    flags << "repeated_bot_reply" if metrics[:repeated_bot_replies].positive?
    flags << "clarification_loop" if metrics[:clarification_turns] >= 2
    flags << "customer_frustration" if metrics[:negative_turns].positive?
    flags << "waiting_for_seller" if metrics[:currently_waiting_for_seller]
    flags << "high_turn_count_without_order" if metrics[:customer_turns] >= 8 && !metrics[:order_confirmed]
    flags
  end

  def score(metrics)
    value = 100
    value -= [ metrics[:clarification_turns] * 8, 24 ].min
    value -= [ metrics[:repeated_bot_replies] * 12, 36 ].min
    value -= [ metrics[:negative_turns] * 6, 18 ].min
    value -= 20 if metrics[:currently_waiting_for_seller]
    value -= 10 if metrics[:customer_turns] >= 8 && !metrics[:order_confirmed]
    value += 5 if metrics[:order_confirmed]
    value.clamp(SCORE_FLOOR, SCORE_CEILING)
  end

  def grade(value)
    return "excellent" if value >= 90
    return "good" if value >= 75
    return "needs_review" if value >= 55

    "poor"
  end

  def conversation_outcome
    return "converted" if successful_order?
    return "handed_over" if conversation.handed_over?
    return "closed_without_order" if conversation.closed?

    "in_progress"
  end

  def handover_entries
    state = conversation.conversation_state.to_h
    Array(state["handover_history"]).presence || Array(state["handover_summary"])
  end

  def successful_order?
    conversation.orders.to_a.any? { |order| !order.status.in?(%w[cancelled revision_pending]) }
  end

  def normalize(value)
    value.to_s.downcase.gsub(/[^a-z0-9\p{Bengali}]+/u, " ").squish
  end
end
