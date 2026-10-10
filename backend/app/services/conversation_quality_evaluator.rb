class ConversationQualityEvaluator
  SCORE_FLOOR = 0
  SCORE_CEILING = 100
  CORRECTION_OUTCOMES = %w[order_updated confirmed_order_updated].freeze
  REPAIR_OUTCOMES = %w[
    clarification_needed name_required invalid_phone invalid_quantity product_not_found product_ambiguous
    variant_not_found confirmation_unclear invalid_order_update
  ].freeze

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
    classifications = customer_messages.map { |message| message.metadata.to_h["classification_feedback"].to_h }
    bot_replies = bot_messages.map { |message| normalize(message.content) }
    assistant_events = bot_messages.filter_map { |message| message.metadata.to_h["ai_assistant"].presence }
    latencies = assistant_events.filter_map { |event| event["latency_ms"] }
    customer_turn_count = customer_messages.count
    correction_turns = intelligence.count { |item| item["outcome"].in?(CORRECTION_OUTCOMES) }
    repair_turns = intelligence.count { |item| item["outcome"].in?(REPAIR_OUTCOMES) }
    clarification_turns = intelligence.count { |item| item["needs_clarification"] || item["outcome"] == "clarification_needed" }
    {
      customer_turns: customer_turn_count,
      bot_turns: bot_messages.count,
      clarification_turns: clarification_turns,
      clarification_rate: percentage(clarification_turns, customer_turn_count),
      correction_turns: correction_turns,
      correction_rate: percentage(correction_turns, customer_turn_count),
      repair_turns: repair_turns,
      repair_rate: percentage(repair_turns, customer_turn_count),
      negative_turns: intelligence.count { |item| item["sentiment"] == "negative" },
      classified_turns: classifications.count { |item| item["predicted_intent"].present? },
      local_classifications: classifications.count { |item| item["classifier"] == "local" },
      gemini_classifications: classifications.count { |item| item["classifier"] == "gemini" },
      classifier_disagreements: classifications.count { |item| item["classifier_disagreement"] },
      reviewed_classifications: classifications.count { |item| item["corrected_intent"].present? },
      incorrect_classifications: classifications.count { |item| item["was_correct"] == false },
      repeated_intents: classifications.count { |item| item["repeated_intent"] },
      followups_after_repair: classifications.count { |item| item["follows_repair"] },
      repeated_bot_replies: bot_replies.tally.values.sum { |count| [ count - 1, 0 ].max },
      ai_assisted_turns: assistant_events.count,
      planner_turns: assistant_events.count { |event| event["planner_used"] },
      tool_calls: assistant_events.sum { |event| Array(event["tool_names"]).count },
      ai_fallbacks: assistant_events.count { |event| event["fallback_reason"].present? },
      guardrail_rejections: assistant_events.count { |event| event["fallback_reason"] == "guardrail_rejected" },
      average_ai_latency_ms: latencies.any? ? (latencies.sum.fdiv(latencies.count)).round : nil,
      handovers: handover_entries.count,
      currently_waiting_for_seller: conversation.handed_over?,
      order_confirmed: successful_order?,
      abandoned_checkout_stage: abandoned_checkout_stage
    }
  end

  def quality_flags(metrics)
    flags = []
    flags << "repeated_bot_reply" if metrics[:repeated_bot_replies].positive?
    flags << "clarification_loop" if metrics[:clarification_turns] >= 2
    flags << "conversation_repair_loop" if metrics[:repair_turns] >= 3
    flags << "repeated_order_correction" if metrics[:correction_turns] >= 2
    flags << "customer_frustration" if metrics[:negative_turns].positive?
    flags << "waiting_for_seller" if metrics[:currently_waiting_for_seller]
    flags << "high_turn_count_without_order" if metrics[:customer_turns] >= 8 && !metrics[:order_confirmed]
    flags << "frequent_ai_fallback" if metrics[:ai_assisted_turns] >= 3 &&
      metrics[:ai_fallbacks].fdiv(metrics[:ai_assisted_turns]) >= 0.5
    flags
  end

  def score(metrics)
    value = 100
    value -= [ metrics[:clarification_turns] * 8, 24 ].min
    value -= [ metrics[:repeated_bot_replies] * 12, 36 ].min
    value -= [ metrics[:negative_turns] * 6, 18 ].min
    value -= [ metrics[:repair_turns] * 4, 16 ].min
    value -= 20 if metrics[:currently_waiting_for_seller]
    value -= 10 if metrics[:customer_turns] >= 8 && !metrics[:order_confirmed]
    value -= [ metrics[:guardrail_rejections] * 4, 12 ].min
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
    Array(state["handover_history"]).presence || [ state["handover_summary"] ].compact
  end

  def successful_order?
    conversation.orders.to_a.any? { |order| !order.status.in?(%w[cancelled revision_pending]) }
  end

  def abandoned_checkout_stage
    return unless conversation.closed? && !successful_order?

    conversation.pending_order&.status || "not_started"
  end

  def percentage(numerator, denominator)
    return 0.0 if denominator.zero?

    ((numerator.to_f / denominator) * 100).round(2)
  end

  def normalize(value)
    value.to_s.downcase.gsub(/[^a-z0-9\p{Bengali}]+/u, " ").squish
  end
end
