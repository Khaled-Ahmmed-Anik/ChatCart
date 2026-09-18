class BotReplyGenerator
  def initialize(pending_order:)
    @pending_order = pending_order
  end

  def content
    case pending_order.status
    when "collecting_product"
      product_selection_prompt
    when "collecting_quantity"
      return product_selection_prompt if pending_order.product.blank?

      "Great choice. How many bottles of #{pending_order.product.name} would you like?"
    when "collecting_name"
      "Perfect. Please share your name for the order."
    when "collecting_phone"
      "Thanks, #{pending_order.customer_name}. Please share your phone number."
    when "collecting_address"
      "Got it. Please share your delivery address."
    when "awaiting_confirmation"
      confirmation_prompt
    when "confirmed"
      "Your order is confirmed. We will submit it for processing shortly."
    when "cancelled"
      "Your order has been cancelled. You can start again anytime."
    else
      "Thanks. We have your order update."
    end
  end

  private

  attr_reader :pending_order

  def product_selection_prompt
    products = Product.active.in_stock.order(:name).pluck(:name)
    return "Which product would you like?" if products.empty?

    "Which product would you like? Available options: #{products.to_sentence}."
  end

  def confirmation_prompt
    [
      "Please confirm your order:",
      "#{pending_order.quantity} x #{pending_order.product.name}",
      "Total: #{pending_order.total_price}",
      "Name: #{pending_order.customer_name}",
      "Phone: #{pending_order.phone}",
      "Address: #{pending_order.address}",
      "Reply confirm to place it, or cancel to stop."
    ].join("\n")
  end
end
