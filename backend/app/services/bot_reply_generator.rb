class BotReplyGenerator
  def initialize(pending_order:, customer_message: nil, outcome: nil, interpretation: nil)
    @pending_order = pending_order
    @customer_message = customer_message
    @outcome = outcome&.to_sym
    @interpretation = interpretation
  end

  def content
    outcome_reply || status_prompt
  end

  private

  attr_reader :pending_order, :customer_message, :outcome, :interpretation

  def outcome_reply
    case outcome
    when :greeting
      "Hi! 👋 Welcome to ChatCart. #{status_prompt}"
    when :help
      help_reply
    when :wellbeing
      "Alhamdulillah, I’m doing well 😊 How can I help with your order today?"
    when :thanks
      "You’re welcome! #{status_prompt}"
    when :goodbye
      "Thanks for chatting with ChatCart. Take care! 👋"
    when :bot_identity
      "I’m ChatCart’s automated shopping assistant. I can help with products, orders, delivery questions, and connect you with the seller when needed."
    when :language_preference
      "Of course—I can continue in English, বাংলা, or Banglish."
    when :complaint
      "I’m sorry you’ve had a frustrating experience. Please briefly describe the issue, and I’ll help route it to the seller."
    when :human_agent
      "I’ll mark this for seller assistance. Please leave a short description of what you need help with."
    when :clarification_needed
      clarification_reply
    when :price_inquiry
      product_information(:price)
    when :stock_inquiry
      product_information(:stock)
    when :product_list_requested
      product_selection_prompt
    when :product_details_requested
      product_details_reply
    when :product_recommendation_requested, :alternative_product_requested
      product_recommendation_reply
    when :product_comparison_requested
      product_comparison_reply
    when :product_variants_requested, :product_images_requested
      "I don’t have those product details configured yet. Please ask the seller, or choose from the available products: #{available_product_names}."
    when :restarted
      "No problem—we’ll start a fresh order. #{product_selection_prompt}"
    when :order_details_requested
      order_details_reply
    when :order_history_requested
      order_history_reply
    when :resume_order_requested
      "Let’s continue where we left off. #{status_prompt}"
    when :payment_methods_requested
      configured_policy("payment methods", ENV["SHOP_PAYMENT_METHODS"])
    when :cash_on_delivery_requested
      configured_policy("cash on delivery", ENV["SHOP_CASH_ON_DELIVERY"])
    when :delivery_charge_requested
      configured_policy("delivery charges", ENV["SHOP_DELIVERY_CHARGES"])
    when :delivery_area_requested
      configured_policy("delivery areas", ENV["SHOP_DELIVERY_AREAS"])
    when :delivery_time_requested
      configured_policy("delivery times", ENV["SHOP_DELIVERY_TIME"])
    when :return_requested
      after_sales_reply("return")
    when :replacement_requested
      after_sales_reply("replacement")
    when :refund_requested
      after_sales_reply("refund")
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
    when :multiple_details_collected
      "Got it. #{status_prompt}"
    when :confirmation_unclear
      "Just to make sure, reply “confirm” to place the order or “cancel” to stop. You can also say something like “change quantity to 3”."
    when :confirmation_deferred
      "No problem—your order is saved, but it isn’t confirmed yet. Send “confirm” whenever you’re ready, or say “change the order” to update it."
    when :order_updated
      "Done—I’ve updated it.\n\n#{confirmation_prompt}"
    when :confirmed_order_updated
      "I’ve updated your confirmed order and reopened it for review. #{status_prompt}"
    when :order_change_requested
      order_change_help
    when :invalid_order_update
      "I couldn’t apply that change. #{order_change_help}"
    when :submitted_order_change_requested
      "That order has already been submitted for processing, so I can’t change it automatically. Please contact the seller for help."
    when :cancelled_order_change_requested
      "That order was cancelled, so it can’t be edited. Send “new order” to start again."
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

  def order_change_help
    "You can say “change quantity to 3”, “change phone to 01712345678”, “change name to Anik”, or “change address to Dhaka”."
  end

  def order_details_reply
    return "You don’t have an order yet. #{product_selection_prompt}" if pending_order.product.blank?

    heading = pending_order.confirmed? ? "Here are your confirmed order details:" : "Here are your current order details:"
    confirmation_prompt.sub("Here’s your order summary:", heading)
  end

  def order_history_reply
    orders = pending_order.conversation.pending_orders.order(created_at: :desc, id: :desc).limit(3)
    return "You don’t have any previous orders yet." if orders.empty?

    lines = orders.map do |order|
      product = order.product&.name || "Product not selected"
      quantity = order.quantity || "—"
      "• Order ##{order.id}: #{quantity} × #{product} — #{order.status.humanize}"
    end
    ([ "Here are your latest orders:" ] + lines).join("\n")
  end

  def product_details_reply
    product = mentioned_product
    return product_selection_prompt if product.blank?

    details = [ "#{product.name} costs #{formatted_price(product.price)}." ]
    details << product.description if product.description.present?
    details << "#{product.stock_quantity} currently in stock."
    details.join(" ")
  end

  def product_recommendation_reply
    products = Product.active.in_stock.order(stock_quantity: :desc, name: :asc).limit(3)
    return "Sorry, no products are currently available." if products.empty?

    "Popular available options are #{products.map { |product| "#{product.name} (#{formatted_price(product.price)})" }.to_sentence}."
  end

  def product_comparison_reply
    products = Product.active.in_stock.order(:name).limit(4)
    return "I need at least two available products to compare." if products.size < 2

    products.map do |product|
      "• #{product.name}: #{formatted_price(product.price)}, #{product.stock_quantity} in stock"
    end.join("\n")
  end

  def clarification_reply
    "I’m not fully sure what you’d like to do. You can ask about products, price, delivery, your order, or say “new order”."
  end

  def configured_policy(topic, value)
    return value if value.present?

    "The #{topic} information hasn’t been configured yet. Please ask the seller for confirmation."
  end

  def after_sales_reply(request_type)
    policy = ENV["SHOP_RETURN_POLICY"]
    introduction = "I can help send your #{request_type} request to the seller."
    return "#{introduction} Please share your order number and what happened." if policy.blank?

    "#{introduction} #{policy} Please share your order number and what happened."
  end

  def available_product_names
    Product.active.in_stock.order(:name).pluck(:name).to_sentence.presence || "none right now"
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
