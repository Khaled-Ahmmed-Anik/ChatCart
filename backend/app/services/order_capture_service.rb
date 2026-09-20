class OrderCaptureService
  def initialize(pending_order)
    @pending_order = pending_order
  end

  def capture
    raise ActiveRecord::RecordInvalid, pending_order unless pending_order.confirmed? && pending_order.ready_for_confirmation?

    Order.transaction do
      order = pending_order.order || Order.new(
        business: business, conversation: pending_order.conversation,
        pending_order: pending_order, number: next_number
      )
      order.update!(
        status: "confirmed",
        customer_name: pending_order.customer_name,
        phone: pending_order.phone,
        address: pending_order.address,
        currency: business.currency,
        subtotal: pending_order.total_price,
        delivery_charge: 0,
        total: pending_order.total_price,
        confirmed_at: Time.current
      )
      order.order_items.destroy_all
      order.order_items.create!(
        product: pending_order.product,
        product_variant: pending_order.product_variant,
        product_name: pending_order.product.name,
        variant_name: pending_order.product_variant&.display_name,
        quantity: pending_order.quantity,
        unit_price: pending_order.unit_price,
        total: pending_order.total_price
      )
      order
    end
  rescue ActiveRecord::RecordNotUnique
    pending_order.reload.order
  end

  private

  attr_reader :pending_order

  def business
    pending_order.conversation.business
  end

  def next_number
    "ORD-#{Time.current.strftime('%Y%m%d')}-#{SecureRandom.hex(3).upcase}"
  end
end
