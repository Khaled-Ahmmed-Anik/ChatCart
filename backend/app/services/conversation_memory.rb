class ConversationMemory
  MAX_INTENT_HISTORY = 12

  def initialize(conversation)
    @conversation = conversation
  end

  def context
    state = conversation.conversation_state.to_h
    {
      preferred_language: state["preferred_language"],
      preferred_tone: state["preferred_tone"],
      address_preference: state["address_preference"],
      pending_question: state["pending_question"],
      last_intent: state["last_intent"],
      last_outcome: state["last_outcome"],
      last_referenced_product: state["last_referenced_product"],
      guided_sales: state["guided_sales"],
      shopping_preferences: state["shopping_preferences"],
      intent_history: Array(state["intent_history"]).last(6),
      customer_profile: remembered_customer_profile,
      previous_order: previous_order_summary
    }.compact
  end

  def remember!(interpretation:, pending_order:, outcome:)
    state = conversation.conversation_state.to_h
    history = Array(state["intent_history"])
    history << {
      "intent" => interpretation&.intent,
      "secondary_intents" => Array(interpretation&.secondary_intents),
      "outcome" => outcome.to_s,
      "at" => Time.current.iso8601
    }.compact

    state["intent_history"] = history.last(MAX_INTENT_HISTORY)
    state["last_referenced_product"] = pending_order.product.name if pending_order.product.present?
    state["known_customer"] = {
      "name" => pending_order.customer_name,
      "has_phone" => pending_order.phone.present?,
      "has_address" => pending_order.address.present?
    }.compact
    conversation.update!(conversation_state: state)
  end

  private

  attr_reader :conversation

  def remembered_customer_profile
    conversation.conversation_state.to_h["known_customer"]
  end

  def previous_order_summary
    order = conversation.pending_orders.where(status: %i[confirmed submitted_to_woocommerce]).order(id: :desc).first
    return if order.blank?

    {
      product: order.product&.name,
      quantity: order.quantity,
      status: order.status
    }.compact
  end
end
