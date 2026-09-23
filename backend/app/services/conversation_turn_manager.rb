class ConversationTurnManager
  MAX_SIDE_QUESTIONS = 6
  MAX_REFERENCE_HISTORY = 5
  PROGRESS_OUTCOMES = %i[
    product_selected variant_selected variant_bundle_selected quantity_collected name_collected phone_collected
    address_collected multiple_details_collected order_updated confirmed_order_updated restarted confirmed cancelled
  ].freeze
  UNRESOLVED_OUTCOMES = {
    clarification_needed: "intent",
    product_ambiguous: "product",
    product_not_found: "product",
    variant_not_found: "variant",
    variant_size_unavailable: "variant_offer",
    invalid_quantity: "quantity",
    quantity_unavailable: "quantity",
    invalid_phone: "phone",
    confirmation_unclear: "confirmation",
    invalid_order_update: "order_update"
  }.freeze

  def initialize(conversation)
    @conversation = conversation
  end

  def record_turn!(message:, pending_order:, outcome:, interpretation:, secondary_outcomes:, interrupted:)
    state = conversation.conversation_state.to_h
    previous = state["turn_manager"].to_h
    reference_history = updated_reference_history(previous, pending_order)
    active_goal = interrupted ? previous["active_goal"].presence || goal_for(pending_order) : goal_for(pending_order)

    turn = previous.merge(
      "active_goal" => active_goal,
      "order_step" => pending_order.status,
      "pending_question" => pending_question_for(pending_order),
      "paused_task" => paused_task(previous, pending_order, outcome, interrupted),
      "side_questions" => updated_side_questions(previous, message, outcome, interpretation, secondary_outcomes, interrupted),
      "reference" => reference_for(pending_order),
      "reference_history" => reference_history,
      "unresolved" => unresolved_for(outcome, interpretation),
      "context_switch_count" => state["context_switch_count"].to_i,
      "last_turn" => {
        "message_id" => message.id,
        "intent" => interpretation&.intent,
        "secondary_intents" => Array(interpretation&.secondary_intents),
        "outcome" => outcome.to_s,
        "secondary_outcomes" => Array(secondary_outcomes).map(&:to_s),
        "interrupted" => interrupted,
        "at" => Time.current.iso8601
      }.compact,
      "updated_at" => Time.current.iso8601
    ).compact

    conversation.update!(conversation_state: state.merge("turn_manager" => turn))
    turn
  end

  private

  attr_reader :conversation

  def goal_for(order)
    return "completed_order" if order.confirmed?
    return "cancelled_order" if order.cancelled?
    return "confirm_order" if order.awaiting_confirmation?
    return "checkout" if order.status.in?(%w[collecting_name collecting_phone collecting_address])
    return "configure_product" if order.status.in?(%w[collecting_variant collecting_quantity])

    "discover_product"
  end

  def pending_question_for(order)
    field = {
      "collecting_product" => "product",
      "collecting_variant" => "variant",
      "collecting_quantity" => "quantity",
      "collecting_name" => "customer_name",
      "collecting_phone" => "phone",
      "collecting_address" => "address",
      "awaiting_confirmation" => "confirmation"
    }[order.status]
    return if field.blank?

    { "field" => field, "product_id" => order.product_id, "variant_id" => order.product_variant_id }.compact
  end

  def paused_task(previous, order, outcome, interrupted)
    if interrupted
      return previous["paused_task"].presence || {
        "goal" => previous["active_goal"].presence || goal_for(order),
        "order_step" => order.status,
        "pending_question" => pending_question_for(order),
        "product_id" => order.product_id,
        "variant_id" => order.product_variant_id,
        "quantity" => order.quantity
      }.compact
    end
    return nil if PROGRESS_OUTCOMES.include?(outcome.to_sym)

    previous["paused_task"]
  end

  def updated_side_questions(previous, message, outcome, interpretation, secondary_outcomes, interrupted)
    questions = Array(previous["side_questions"])
    return questions unless interrupted

    questions << {
      "message_id" => message.id,
      "intent" => interpretation&.intent,
      "outcome" => outcome.to_s,
      "secondary_outcomes" => Array(secondary_outcomes).map(&:to_s),
      "answered" => true,
      "at" => Time.current.iso8601
    }.compact
    questions.last(MAX_SIDE_QUESTIONS)
  end

  def reference_for(order)
    return if order.product.blank?

    {
      "product_id" => order.product_id,
      "product_name" => order.product.name,
      "variant_id" => order.product_variant_id,
      "variant_name" => order.product_variant&.display_name
    }.compact
  end

  def updated_reference_history(previous, order)
    history = Array(previous["reference_history"])
    reference = reference_for(order)
    return history if reference.blank? || history.last == reference

    (history + [ reference ]).last(MAX_REFERENCE_HISTORY)
  end

  def unresolved_for(outcome, interpretation)
    kind = UNRESOLVED_OUTCOMES[outcome.to_sym]
    return if kind.blank?

    {
      "kind" => kind,
      "possible_intents" => Array(interpretation&.possible_intents).presence,
      "needs_clarification" => true
    }.compact
  end
end
