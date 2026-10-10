class AnalyticsSnapshot
  def initialize(business:)
    @business = business
  end

  def call
    conversations = business.conversations
    orders = business.orders
    customers = conversations.distinct.count(:external_customer_id)
    ordering_customers = orders.joins(:conversation).distinct.count("conversations.external_customer_id")
    repeat_customers = orders.joins(:conversation).group("conversations.external_customer_id")
      .having("COUNT(orders.id) > 1").count.length
    revenue_orders = orders.where.not(status: "cancelled")

    {
      conversations: conversations.count,
      unique_customers: customers,
      confirmed_orders: orders.count,
      conversation_to_order_rate: percentage(orders.select(:conversation_id).distinct.count, conversations.count),
      ordering_customers: ordering_customers,
      repeat_customers: repeat_customers,
      repeat_customer_rate: percentage(repeat_customers, ordering_customers),
      revenue: revenue_orders.sum(:total).to_s,
      average_order_value: revenue_orders.average(:total).to_d.to_s,
      orders_by_channel: orders.joins(:conversation).group("conversations.channel").count,
      orders_by_status: orders.group(:status).count,
      top_products: top_products,
      handovers: handover_metrics(conversations),
      conversation_quality: conversation_quality_metrics(conversations)
    }
  end

  private

  attr_reader :business

  def percentage(numerator, denominator)
    return 0.0 if denominator.zero?

    ((numerator.to_f / denominator) * 100).round(2)
  end

  def top_products
    OrderItem.joins(:order).where(orders: { business_id: business.id })
      .group(:product_name).order(Arel.sql("SUM(quantity) DESC")).limit(10).sum(:quantity)
  end

  def handover_metrics(conversations)
    entries = conversations.pluck(:conversation_state).flat_map do |state|
      history = Array(state.to_h["handover_history"])
      history.presence || [ state.to_h["handover_summary"] ].compact
    end
    response_seconds = entries.filter_map do |entry|
      started = Time.zone.parse(entry["created_at"].to_s)
      replied = Time.zone.parse(entry["first_seller_response_at"].to_s)
      (replied - started).round if started && replied
    rescue ArgumentError
      nil
    end

    {
      total: entries.count,
      waiting_now: conversations.where(status: :handed_over).count,
      responded: response_seconds.count,
      average_first_response_seconds: response_seconds.any? ? (response_seconds.sum.to_f / response_seconds.count).round : nil,
      reasons: entries.group_by { |entry| entry["reason"].presence || "unknown" }.transform_values(&:count)
    }
  end

  def conversation_quality_metrics(conversations)
    evaluations = conversations.includes(:messages, :orders).map do |conversation|
      ConversationQualityEvaluator.new(conversation: conversation).call
    end
    scores = evaluations.map { |evaluation| evaluation[:score] }
    reviews = evaluations.filter_map { |evaluation| evaluation[:review]&.dig("label") }
    feedback = evaluations.filter_map { |evaluation| evaluation[:customer_feedback]&.dig("rating") }
    metrics = evaluations.map { |evaluation| evaluation[:metrics] }
    customer_turns = metrics.sum { |item| item[:customer_turns] }
    ai_assisted_turns = metrics.sum { |item| item[:ai_assisted_turns] }
    classified_turns = metrics.sum { |item| item[:classified_turns] }
    reviewed_classifications = metrics.sum { |item| item[:reviewed_classifications] }

    {
      average_score: scores.any? ? (scores.sum.to_f / scores.count).round(1) : nil,
      needs_review: evaluations.count { |evaluation| evaluation[:flags].any? || evaluation[:grade].in?(%w[needs_review poor]) },
      repeated_reply_cases: evaluations.count { |evaluation| evaluation[:flags].include?("repeated_bot_reply") },
      clarification_loop_cases: evaluations.count { |evaluation| evaluation[:flags].include?("clarification_loop") },
      conversation_repair_loop_cases: evaluations.count { |evaluation| evaluation[:flags].include?("conversation_repair_loop") },
      repeated_order_correction_cases: evaluations.count { |evaluation| evaluation[:flags].include?("repeated_order_correction") },
      clarification_rate: percentage(metrics.sum { |item| item[:clarification_turns] }, customer_turns),
      correction_rate: percentage(metrics.sum { |item| item[:correction_turns] }, customer_turns),
      repair_rate: percentage(metrics.sum { |item| item[:repair_turns] }, customer_turns),
      ai_fallback_rate: percentage(metrics.sum { |item| item[:ai_fallbacks] }, ai_assisted_turns),
      local_classification_rate: percentage(metrics.sum { |item| item[:local_classifications] }, classified_turns),
      classifier_disagreement_rate: percentage(metrics.sum { |item| item[:classifier_disagreements] }, classified_turns),
      reviewed_classifications: reviewed_classifications,
      classification_correction_rate: percentage(
        metrics.sum { |item| item[:incorrect_classifications] }, reviewed_classifications
      ),
      abandoned_checkout_stages: metrics.filter_map { |item| item[:abandoned_checkout_stage] }.tally,
      reviewed: reviews.count,
      review_labels: reviews.tally,
      helpful_feedback: feedback.count("helpful"),
      unhelpful_feedback: feedback.count("unhelpful")
    }
  end
end
