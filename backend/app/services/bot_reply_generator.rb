class BotReplyGenerator
  def initialize(pending_order:, customer_message: nil, outcome: nil)
    @pending_order = pending_order
    @customer_message = customer_message
    @outcome = outcome&.to_sym
  end

  def content
    outcome_reply || status_prompt
  end

  private

  attr_reader :pending_order, :customer_message, :outcome

  def outcome_reply
    case outcome
    when :greeting
      "Hi! 👋 Welcome to ChatCart. #{status_prompt}"
    when :help
      help_reply
    when :thanks
      "You’re welcome! #{status_prompt}"
    when :price_inquiry
      product_information(:price)
    when :stock_inquiry
      product_information(:stock)
    when :restarted
      "No problem—we’ll start a fresh order. #{product_selection_prompt}"
    when :product_selected
      "Nice choice! #{quantity_prompt}"
    when :product_unavailable
      "Sorry, that product isn’t available right now. #{product_selection_prompt}"
    when :product_not_found
      "I couldn’t match that to one of our available products. #{product_selection_prompt}"
    when :invalid_quantity
      "I didn’t catch the quantity. Please send a number, such as “2”, or write “two”."
    when :quantity_unavailable
      "Sorry, we only have #{pending_order.product.stock_quantity} #{bottle_word(pending_order.product.stock_quantity)} available. How many would you like?"
    when :quantity_collected
      "Perfect—#{pending_order.quantity} #{bottle_word(pending_order.quantity)}. What name should I put on the order?"
    when :name_collected
      "Thanks, #{pending_order.customer_name}! What phone number should we use for the delivery?"
    when :invalid_phone
      "That doesn’t look like a complete phone number. Please send one like 01712345678."
    when :phone_collected
      "Got it. What’s the full delivery address?"
    when :address_collected
      confirmation_prompt
    when :confirmation_unclear
      "Just to make sure, reply “confirm” to place the order or “cancel” to stop. You can also say something like “change quantity to 3”."
    when :order_updated
      "Done—I’ve updated it.\n\n#{confirmation_prompt}"
    when :confirmed
      "Thanks! Your order is confirmed ✅ We’ll send it for processing shortly."
    when :cancelled
      "Your order has been cancelled. If you change your mind, just send “new order”."
    end
  end

  def status_prompt
    case pending_order.status
    when "collecting_product"
      product_selection_prompt
    when "collecting_quantity"
      pending_order.product.present? ? quantity_prompt : product_selection_prompt
    when "collecting_name"
      "What name should I put on the order?"
    when "collecting_phone"
      "What phone number should we use for the delivery?"
    when "collecting_address"
      "What’s the full delivery address?"
    when "awaiting_confirmation"
      confirmation_prompt
    when "confirmed"
      "Your order is already confirmed ✅"
    when "cancelled"
      "This order is cancelled. Send “new order” whenever you’d like to begin again."
    else
      "How can I help with your order?"
    end
  end

  def product_selection_prompt
    products = Product.active.in_stock.order(:name)
    return "What product would you like to order?" if products.empty?

    options = products.map { |product| "#{product.name} (#{formatted_price(product.price)})" }.to_sentence
    "What would you like to order? We currently have #{options}."
  end

  def quantity_prompt
    "#{pending_order.product.name} is #{formatted_price(pending_order.product.price)} per bottle. How many would you like?"
  end

  def confirmation_prompt
    [
      "Here’s your order summary:",
      "• #{pending_order.quantity} × #{pending_order.product.name}",
      "• Total: #{formatted_price(pending_order.total_price)}",
      "• Name: #{pending_order.customer_name}",
      "• Phone: #{pending_order.phone}",
      "• Address: #{pending_order.address}",
      "",
      "Does everything look right? Reply “confirm” to place it or “cancel” to stop."
    ].join("\n")
  end

  def help_reply
    intro = "I can help you choose a product and place an order."
    "#{intro} #{status_prompt} You can send “new order” at any time to start over."
  end

  def product_information(kind)
    product = mentioned_product
    return product_selection_prompt if product.blank?

    information = if kind == :price
      "#{product.name} is #{formatted_price(product.price)} per bottle."
    elsif product.stock_quantity.positive?
      "Yes, #{product.name} is available—we have #{product.stock_quantity} in stock."
    else
      "Sorry, #{product.name} is currently out of stock."
    end

    "#{information} #{status_prompt}"
  end

  def mentioned_product
    content = customer_message&.content.to_s.downcase
    Product.find_each.find { |product| content.include?(product.name.downcase) }
  end

  def formatted_price(value)
    amount = value.to_d
    amount = amount.to_i if amount.frac.zero?
    "৳#{amount}"
  end

  def bottle_word(quantity)
    quantity == 1 ? "bottle" : "bottles"
  end
end
