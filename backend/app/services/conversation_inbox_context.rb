class ConversationInboxContext
  RECENT_ORDER_LIMIT = 5

  def initialize(conversation:, pending_order:)
    @conversation = conversation
    @pending_order = pending_order
  end

  def call
    recorded = conversation.orders.where(business_id: conversation.business_id).includes(:order_items).recent_first
    latest = recorded.first
    {
      customer: {
        name: conversation.conversation_state.to_h.dig("customer_profile", "name").presence || pending_order&.customer_name.presence || latest&.customer_name,
        phone: pending_order&.phone.presence || latest&.phone,
        address: pending_order&.address.presence || latest&.address,
        first_seen_at: conversation.created_at
      },
      order: current_order,
      recorded_order_count: recorded.count,
      recent_orders: recorded.limit(RECENT_ORDER_LIMIT).map { |order| recorded_order(order) }
    }
  end

  private

  attr_reader :conversation, :pending_order

  def current_order
    return unless pending_order

    saved = pending_order.order
    return recorded_order(saved) if saved && saved.business_id == conversation.business_id

    items = pending_order.item_snapshot
    {
      id: pending_order.id, status: pending_order.status, pricing: "catalogue",
      items: items.map { |item| item.except("variant_id", "total_price").merge("total" => item["total_price"]) },
      subtotal: items.sum { |item| item.fetch("total_price").to_d }.to_s,
      currency: conversation.business.currency
    }
  end

  def recorded_order(order)
    order.slice(:id, :number, :status, :subtotal, :delivery_charge, :total, :currency, :confirmed_at).merge(
      pricing: "recorded",
      items: order.order_items.map { |item| item.slice(:product_name, :variant_name, :quantity, :unit_price, :total) }
    )
  end
end
