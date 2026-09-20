class GuidedSalesConversation
  STAGES = %w[discover compare select configure checkout confirm complete].freeze

  OUTCOME_STAGES = {
    product_recommendation_requested: "discover",
    alternative_product_requested: "discover",
    product_comparison_requested: "compare",
    recommendations_rejected: "discover",
    shortlist_updated: "compare",
    product_selected: "select",
    variant_selected: "configure",
    quantity_collected: "checkout",
    address_collected: "confirm",
    confirmed: "complete"
  }.freeze

  def initialize(conversation)
    @conversation = conversation
  end

  def stage
    state["stage"]
  end

  def active?
    stage.in?(STAGES - %w[complete])
  end

  def transition!(new_stage, context: {})
    new_stage = new_stage.to_s
    raise ArgumentError, "Unsupported guided sales stage: #{new_stage}" unless new_stage.in?(STAGES)

    conversation_state = conversation.conversation_state.to_h
    sales_state = state.merge(
      "stage" => new_stage,
      "context" => state.fetch("context", {}).merge(context.stringify_keys),
      "updated_at" => Time.current.iso8601
    )
    conversation.update!(conversation_state: conversation_state.merge("guided_sales" => sales_state))
  end

  def context
    state.fetch("context", {})
  end

  def suspend_order!(pending_order)
    return if pending_order.product.blank?

    transition!("discover", context: {
      suspended_order: {
        product_id: pending_order.product_id,
        product_variant_id: pending_order.product_variant_id,
        quantity: pending_order.quantity,
        status: pending_order.status
      }
    })
  end

  def resume_order!(pending_order)
    snapshot = context["suspended_order"]
    return false if snapshot.blank?

    pending_order.update!(
      product_id: snapshot["product_id"],
      product_variant_id: snapshot["product_variant_id"],
      quantity: snapshot["quantity"],
      status: snapshot["status"]
    )
    transition!(stage_for_order(pending_order), context: { suspended_order: nil })
    true
  end

  def remember_recommendations!(product_ids)
    transition!(stage.presence || "discover", context: { last_recommended_product_ids: Array(product_ids).uniq })
  end

  def reject_last_recommendations!
    rejected = (Array(context["rejected_product_ids"]) + Array(context["last_recommended_product_ids"])).uniq
    transition!("discover", context: { rejected_product_ids: rejected, last_recommended_product_ids: [] })
    rejected
  end

  def add_to_shortlist!(product_ids)
    shortlist = (Array(context["shortlist_product_ids"]) + Array(product_ids)).uniq
    transition!("compare", context: { shortlist_product_ids: shortlist })
    shortlist
  end

  def remove_from_shortlist!(product_ids)
    shortlist = Array(context["shortlist_product_ids"]) - Array(product_ids)
    transition!(shortlist.size > 1 ? "compare" : "discover", context: { shortlist_product_ids: shortlist })
    shortlist
  end

  def sync!(outcome:, pending_order:)
    next_stage = OUTCOME_STAGES[outcome.to_sym] || stage_for_order(pending_order)
    transition!(next_stage) if next_stage.present? && next_stage != stage
  end

  def reset!
    conversation.update!(conversation_state: conversation.conversation_state.to_h.except("guided_sales", "shopping_preferences"))
  end

  private

  attr_reader :conversation

  def state
    conversation.conversation_state.to_h.fetch("guided_sales", {})
  end

  def stage_for_order(pending_order)
    return "complete" if pending_order.confirmed?
    return "confirm" if pending_order.awaiting_confirmation?
    return "checkout" if pending_order.status.in?(%w[collecting_name collecting_phone collecting_address])
    return "configure" if pending_order.status.in?(%w[collecting_variant collecting_quantity])
    "discover" if pending_order.collecting_product? && active?
  end
end
