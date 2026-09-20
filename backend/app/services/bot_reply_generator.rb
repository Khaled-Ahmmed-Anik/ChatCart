class BotReplyGenerator
  def initialize(pending_order:, customer_message: nil, outcome: nil, interpretation: nil, address_preference: nil)
    @pending_order = pending_order
    @customer_message = customer_message
    @outcome = outcome&.to_sym
    @interpretation = interpretation
    @address_preference = address_preference
  end

  def content
    outcome_reply || status_prompt
  end

  private

  attr_reader :pending_order, :customer_message, :outcome, :interpretation, :address_preference

  def outcome_reply
    case outcome
    when :greeting
      "Assalamu alaikum#{address_suffix}! 👋 Welcome to ChatCart. #{status_prompt}"
    when :help
      help_reply
    when :wellbeing
      "Alhamdulillah, I’m doing well#{address_suffix} 😊 How can I help with your order today?"
    when :thanks
      "You’re very welcome#{address_suffix}! #{status_prompt}"
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
    when :human_handover_started
      "I’ve passed this conversation to the seller so they can help properly. They’ll continue with you here as soon as possible."
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
    when :repeat_order_prepared
      "I’ve prepared the same order again for you. #{confirmation_prompt}"
    when :order_details_requested
      order_details_reply
    when :order_history_requested
      order_history_reply
    when :resume_order_requested
      "Let’s continue where we left off. #{status_prompt}"
    when :payment_methods_requested
      configured_policy("payment methods", policy.payment_methods || ENV["SHOP_PAYMENT_METHODS"])
    when :cash_on_delivery_requested
      configured_policy("cash on delivery", policy.cash_on_delivery || ENV["SHOP_CASH_ON_DELIVERY"])
    when :delivery_charge_requested
      configured_policy("delivery charges", policy.delivery_charges || ENV["SHOP_DELIVERY_CHARGES"])
    when :delivery_area_requested
      configured_policy("delivery areas", policy.delivery_areas || ENV["SHOP_DELIVERY_AREAS"])
    when :delivery_time_requested
      configured_policy("delivery times", policy.delivery_time || ENV["SHOP_DELIVERY_TIME"])
    when :return_requested
      after_sales_reply("return")
    when :replacement_requested
      after_sales_reply("replacement")
    when :refund_requested
      after_sales_reply("refund")
    when :product_selected
      pending_order.product_variant.present? || !pending_order.product_variants_required? ?
        "Nice choice! #{quantity_prompt}" : "Nice choice! #{variant_selection_prompt}"
    when :variant_selected
      "Great—#{pending_order.product_variant.display_name}. #{quantity_prompt}"
    when :variant_not_found
      "I couldn’t match that size. #{variant_selection_prompt}"
    when :product_unavailable
      "Sorry, that product isn’t available right now. #{product_selection_prompt}"
    when :product_not_found
      "I couldn’t match that to one of our available products. #{product_selection_prompt}"
    when :invalid_quantity
      "I didn’t catch the quantity. Please send a number, such as “2”, or write “two”."
    when :quantity_unavailable
      "Sorry, we only have #{selected_stock} available for that option. How many would you like?"
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
    when "collecting_variant"
      variant_selection_prompt
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
    products = catalog.active.includes(:product_variants).order(:name).select { |product| product.total_available_stock.positive? }
    return "What product would you like to order?" if products.empty?

    options = products.map do |product|
      prefix = product.product_variants.any? ? "from " : ""
      "#{product.name} (#{prefix}#{formatted_price(product.starting_price)})"
    end.to_sentence
    "What would you like to order? We currently have #{options}."
  end

  def quantity_prompt
    selection = [ pending_order.product.name, pending_order.product_variant&.display_name ].compact.join(" ")
    unit = pending_order.product_variant.present? ? "each" : "per bottle"
    "#{selection} is #{formatted_price(pending_order.unit_price)} #{unit}. How many would you like?"
  end

  def variant_selection_prompt
    variants = pending_order.product&.available_variants.to_a
    return "Which size would you like?" if variants.empty?

    options = variants.map { |variant| "#{variant.display_name} (#{formatted_price(variant.price)})" }.to_sentence
    "Which size would you like? Available options are #{options}."
  end

  def confirmation_prompt
    [
      "Here’s your order summary:",
      "• #{pending_order.quantity} × #{[ pending_order.product.name, pending_order.product_variant&.display_name ].compact.join(' ')}",
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

    details = [ "#{product.name} starts from #{formatted_price(product.starting_price)}." ]
    details << product.description if product.description.present?
    details << product.benefits if product.benefits.present?
    details << "#{product.total_available_stock} currently in stock."
    details.join(" ")
  end

  def product_recommendation_reply
    result = ProductRecommendationService.new(
      business: pending_order.conversation.business,
      message: customer_message&.content
    ).call
    if result.offers.empty?
      return "I couldn’t find an available option in that range. Our available prices start from #{formatted_price(result.minimum_price)}." if result.minimum_price

      return "Sorry, no products are currently available."
    end

    options = result.offers.map { |offer| "#{offer.label} for #{formatted_price(offer.price)}" }.to_sentence
    introduction = if result.floor_request
      "Our available prices start from #{formatted_price(result.minimum_price)}. You can consider"
    elsif result.budget_detected
      "Within your requested price, you can consider"
    else
      "Based on what you’re looking for, I recommend"
    end
    "#{introduction} #{options}. Which one would you like to know more about?"
  end

  def product_comparison_reply
    products = catalog.active.includes(:product_variants).order(:name).select { |product| product.total_available_stock.positive? }.first(4)
    return "I need at least two available products to compare." if products.size < 2

    products.map do |product|
      "• #{product.name}: from #{formatted_price(product.starting_price)}, #{product.total_available_stock} in stock"
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
    policy_text = policy.return_policy || ENV["SHOP_RETURN_POLICY"]
    introduction = "I can help send your #{request_type} request to the seller."
    return "#{introduction} Please share your order number and what happened." if policy_text.blank?

    "#{introduction} #{policy_text} Please share your order number and what happened."
  end

  def available_product_names
    catalog.active.includes(:product_variants).order(:name).select { |product| product.total_available_stock.positive? }
      .map(&:name).to_sentence.presence || "none right now"
  end

  def product_information(kind)
    product = mentioned_product
    return product_selection_prompt if product.blank?

    information = if kind == :price
      if product.product_variants.any?
        product.available_variants.map { |variant| "#{variant.display_name}: #{formatted_price(variant.price)}" }.to_sentence
      else
        "#{product.name} is #{formatted_price(product.price)} per bottle."
      end
    elsif product.total_available_stock.positive?
      "Yes, #{product.name} is available—we have #{product.total_available_stock} in stock across its options."
    else
      "Sorry, #{product.name} is currently out of stock."
    end

    "#{information} #{status_prompt}"
  end

  def mentioned_product
    content = customer_message&.content.to_s.downcase
    catalog.includes(:product_variants).find_each.find { |product| content.include?(product.name.downcase) }
  end

  def catalog
    pending_order.conversation.business.products
  end

  def policy
    pending_order.conversation.business.policy
  end

  def formatted_price(value)
    amount = value.to_d
    amount = amount.to_i if amount.frac.zero?
    "৳#{amount}"
  end

  def bottle_word(quantity)
    quantity == 1 ? "bottle" : "bottles"
  end

  def selected_stock
    pending_order.product_variant&.stock_quantity || pending_order.product&.stock_quantity || 0
  end

  def address_suffix
    display = ConversationAddressPreference.display(address_preference)
    display.present? ? ", #{display}" : ""
  end
end
