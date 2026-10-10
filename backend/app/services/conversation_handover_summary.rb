class ConversationHandoverSummary
  def initialize(conversation:, reason:)
    @conversation = conversation
    @reason = reason
  end

  def generate!
    summary = {
      "reason" => reason,
      "last_customer_message" => conversation.messages.customer.order(id: :desc).pick(:content),
      "recent_topics" => recent_topics,
      "active_order" => active_order_summary,
      "created_at" => Time.current.iso8601
    }.compact
    state = conversation.conversation_state.to_h
    history = Array(state["handover_history"]) << summary
    state = state.merge("handover_summary" => summary, "handover_history" => history.last(20))
    conversation.update!(conversation_state: state)
    summary
  end

  private

  attr_reader :conversation, :reason

  def recent_topics
    conversation.messages.customer.order(id: :desc).limit(8).filter_map do |message|
      message.metadata.to_h.dig("conversation_intelligence", "intent")
    end.uniq.first(4)
  end

  def active_order_summary
    order = conversation.pending_order
    return if order.blank?

    {
      "status" => order.status,
      "product" => order.product&.name,
      "quantity" => order.quantity,
      "items" => order.item_snapshot,
      "customer_name" => order.customer_name
    }.compact
  end
end
