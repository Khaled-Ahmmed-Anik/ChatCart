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
      greeting_reply
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
      I18n.t("bot_replies.human_handover_started", locale: :bn)
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
    when :recommendations_rejected
      "No problem—I won’t repeat those options. What felt wrong: the scent style, strength, price, product type, or something else?"
    when :shortlist_updated, :shortlist_requested
      shortlist_reply
    when :product_comparison_requested
      product_comparison_reply
    when :product_variants_requested
      product_variants_reply
    when :product_images_requested
      "I don’t have product images configured here yet. Please tell me the product name and I can still help with its details."
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
    when :product_ambiguous
      product_ambiguity_reply
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
    products = available_products
    return "What product would you like to order?" if products.empty?

    [
      "Here are our available products:",
      *product_catalog_lines(products),
      "",
      "Which one would you like? You can also tell me your budget or what kind of product you prefer."
    ].join("\n")
  end

  def greeting_reply
    return "Assalamu alaikum#{address_suffix}! 👋 Welcome to #{business_name}. #{status_prompt}" unless pending_order.collecting_product?

    products = available_products
    return "Assalamu alaikum#{address_suffix}! 👋 Welcome to #{business_name}. How can I help you today?" if products.empty?

    visible_products = products.first(Constants::Conversation::INITIAL_CATALOG_LIMIT)
    remaining_count = products.size - visible_products.size
    more_products_line = "• +#{remaining_count} more available—send “show all products” to see them" if remaining_count.positive?

    [
      "Assalamu alaikum#{address_suffix}! 👋 Welcome to #{business_name}.",
      "",
      "Here are a few products you can order:",
      *product_catalog_lines(visible_products),
      more_products_line,
      "",
      "Know what you want? Send the product name. Not sure? Tell me whether you want a single perfume or combo, the scent style or occasion, and your budget (for example, “fresh for office under ৳1500”)."
    ].compact.join("\n")
  end

  def product_catalog_lines(products)
    products.map do |product|
      prefix = product.product_variants.any? ? "from " : ""
      "• #{product.name} — #{prefix}#{formatted_price(product.starting_price)}"
    end
  end

  def available_products
    catalog.active.includes(:product_variants).order(:name).select { |product| product.total_available_stock.positive? }
  end

  def business_name
    pending_order.conversation.business.name
  end

  def quantity_prompt
    selection = [ pending_order.product.name, pending_order.product_variant&.display_name ].compact.join(" ")
    unit = pending_order.product_variant.present? ? "each" : "per bottle"
    "#{selection} is #{formatted_price(pending_order.unit_price)} #{unit}. How many would you like?"
  end

  def variant_selection_prompt
    variants = pending_order.product&.available_variants.to_a.sort_by { |variant| variant_size_number(variant) }
    return "Which size would you like?" if variants.empty?

    options = variants.each_with_index.map do |variant, index|
      guidance = if index.zero? && variants.many?
        " — good for trying it first"
      elsif index == variants.length - 1 && variants.many?
        " — best value for regular use"
      end
      "• #{variant.display_name}: #{formatted_price(variant.price)}#{guidance}"
    end
    ([ "Which size would suit you?", *options, "", "You can reply with the size, price, or say “small”, “medium”, or “best value”." ]).join("\n")
  end

  def variant_size_number(variant)
    variant.size.to_s[/\d+(?:\.\d+)?/]&.to_d || variant.position
  end

  def confirmation_prompt
    [
      "Here’s your order summary:",
      "• #{pending_order.quantity} × #{[ pending_order.product.name, pending_order.product_variant&.display_name ].compact.join(' ')}",
      *combo_component_lines,
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
    if product.combo?
      component_names = product.combo_items.includes(:component_product).map { |item| "#{item.quantity} × #{item.component_product.name}" }
      details << "The combo includes #{component_names.to_sentence}." if component_names.any?
    end
    details << "#{product.total_available_stock} currently in stock."
    details.join(" ")
  end

  def product_recommendation_reply
    conversation_state = pending_order.conversation.conversation_state.to_h
    guided_context = conversation_state.dig("guided_sales", "context").to_h
    preferences = conversation_state["shopping_preferences"].to_h.merge(
      "rejected_product_ids" => guided_context["rejected_product_ids"],
      "previous_recommendations" => guided_context["last_recommendations"]
    )
    result = ProductRecommendationService.new(
      business: pending_order.conversation.business,
      message: customer_message&.content,
      preferences: preferences
    ).call
    return result.clarification_question if result.clarification_question.present?

    if result.offers.empty?
      return "I couldn’t find an available option in that range. Our available prices start from #{formatted_price(result.minimum_price)}." if result.minimum_price

      return "Sorry, no products are currently available."
    end

    previous_recommendations = Array(guided_context["last_recommendations"])
    recommendation_snapshots = result.offers.map { |offer| recommendation_snapshot(offer) }
    GuidedSalesConversation.new(pending_order.conversation).remember_recommendations!(
      result.offers.map { |offer| offer.product.id }, offers: recommendation_snapshots
    )

    options = result.offers.map do |offer|
      description = offer.product.short_description.presence || offer.product.description.to_s
      summary = description.squish.truncate(180)
      product_kind = offer.product.combo? ? "Combo" : "Single fragrance"
      sizes = offer.product.available_variants.to_a.sort_by { |variant| variant_size_number(variant) }.map(&:display_name).uniq
      detail_lines = [ "  #{product_kind}. #{summary}" ]
      tradeoff = recommendation_tradeoff(offer, previous_recommendations, result)
      detail_lines << "  #{tradeoff}" if tradeoff.present?
      if result.budget_detected && offer.variant.present?
        detail_lines << "  Best size within your budget: #{offer.variant.display_name} for #{formatted_price(offer.price)}."
      end
      detail_lines << "  Sizes: #{sizes.to_sentence}." if sizes.any?
      heading = if result.budget_detected
        "• #{offer.product.name} — #{formatted_price(offer.price)}"
      else
        "• #{offer.product.name} — starts from #{formatted_price(offer.product.starting_price)}"
      end
      "#{heading}\n#{detail_lines.join("\n")}"
    end
    introduction = if !result.exact_match && result.requested_maximum.present?
      "I couldn’t find an exact match within #{formatted_price(result.requested_maximum)}. The closest available option is"
    elsif !result.exact_match && preferences["price_direction"].present?
      "I couldn’t find an exact #{preferences['price_direction']} alternative. The closest available options are"
    elsif preferences["price_direction"] == "lower"
      "Here are lower-priced alternatives"
    elsif preferences["price_direction"] == "higher"
      "Here are more premium alternatives"
    elsif preferences["projection_preference"] == "stronger"
      "Here are stronger-projecting alternatives"
    elsif preferences["projection_preference"] == "softer"
      "Here are softer alternatives"
    elsif result.floor_request
      "Our available prices start from #{formatted_price(result.minimum_price)}. You can consider"
    elsif result.budget_detected
      "Within your requested price, you can consider"
    else
      "Based on what you’re looking for, I recommend"
    end
    ([ "#{introduction}:", *options, "", "Which one sounds closest to what you want?" ]).join("\n")
  end

  def recommendation_snapshot(offer)
    attributes = offer.product.product_attributes.to_h
    {
      product_id: offer.product.id,
      variant_id: offer.variant&.id,
      price: offer.price.to_s,
      projection: attributes["projection"],
      scent_families: Array(attributes["scent_families"])
    }
  end

  def recommendation_tradeoff(offer, previous_recommendations, result)
    if !result.exact_match && result.requested_maximum.present? && offer.price > result.requested_maximum
      difference = offer.price - result.requested_maximum
      return "This is #{formatted_price(difference)} above your budget, but it is the nearest in-stock choice."
    end

    previous_prices = previous_recommendations.filter_map do |item|
      item.to_h.with_indifferent_access[:price].presence&.to_d
    end
    return if previous_prices.empty?

    if offer.price < previous_prices.min
      "It costs #{formatted_price(previous_prices.min - offer.price)} less than the previous options."
    elsif offer.price > previous_prices.max
      "It costs #{formatted_price(offer.price - previous_prices.max)} more than the previous options."
    end
  end

  def shortlist_reply
    ids = GuidedSalesConversation.new(pending_order.conversation).context["shortlist_product_ids"]
    products = catalog.where(id: ids).order(:name)
    return "Your shortlist is empty. Ask me for recommendations, then say “keep the first one” or name a product." if products.empty?

    lines = products.map { |product| "• #{product.name} — from #{formatted_price(product.starting_price)}" }
    ([ "Your shortlist:", *lines, "", "You can compare these, remove one, or choose one to order." ]).join("\n")
  end

  def product_ambiguity_reply
    result = ProductResolutionService.new(
      business: pending_order.conversation.business,
      query: customer_message&.content,
      recent_product_name: pending_order.conversation.conversation_state.to_h["last_referenced_product"]
    ).resolve
    names = result.candidates.map { |candidate| candidate.product.name }.uniq
    return product_selection_prompt if names.empty?

    "Which product did you mean: #{names.to_sentence(last_word_connector: ', or ')}?"
  end

  def product_comparison_reply
    products = products_mentioned_in_message
    return "Tell me the two product names you want to compare, for example: “The Office vs Bleu Inspired”." if products.size < 2

    lines = products.first(3).map do |product|
      attributes = product.product_attributes.to_h
      scent = Array(attributes["scent_families"]).first(4).to_sentence.presence || product.category.presence || "fragrance"
      occasions = Array(attributes["occasions"]).first(3).to_sentence
      performance = [ attributes["longevity_hours"].presence&.then { |hours| "#{hours} hours" }, attributes["projection"] ].compact.to_sentence
      details = [ scent, occasions.present? ? "best for #{occasions}" : nil, performance.presence ].compact.join("; ")
      "• #{product.name} — from #{formatted_price(product.starting_price)}\n  #{details}."
    end

    ([ "Here’s the practical difference:", *lines, "", comparison_guidance(products.first(3)) ]).join("\n")
  end

  def products_mentioned_in_message
    normalized = customer_message&.content.to_s.downcase
    catalog.available_for_sale.includes(:product_variants).select do |product|
      product.total_available_stock.positive? && product.searchable_names.any? do |name|
        normalized.include?(name.downcase)
      end
    end
  end

  def comparison_guidance(products)
    summaries = products.filter_map do |product|
      families = Array(product.product_attributes.to_h["scent_families"])
      next if families.empty?

      "choose #{product.name} for #{families.first(2).to_sentence}"
    end
    return "Which one matches your taste better?" if summaries.empty?

    "In short: #{summaries.to_sentence}. Which direction sounds better to you?"
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

  def product_variants_reply
    return general_product_variants_reply if general_variant_request?

    product = contextual_product
    return "Sure—which product would you like the size options for? Just send me its name." if product.blank?

    variants = product.available_variants.to_a.sort_by { |variant| variant_size_number(variant) }
    if variants.empty?
      return "#{product.name} currently has one standard option at #{formatted_price(product.price)}. How many would you like?"
    end

    options = variants.map do |variant|
      "• #{variant.display_name} — #{formatted_price(variant.price)} (#{variant.stock_quantity} in stock)"
    end
    ([ "#{product.name} is available in:", *options, "", "Which size would you prefer?" ]).join("\n")
  end

  def general_product_variants_reply
    grouped_variants = catalog.active.includes(:product_variants).flat_map(&:available_variants).group_by do |variant|
      variant.display_name.upcase
    end
    return "Sizes vary by product. Send me a product name and I’ll show its exact available options." if grouped_variants.empty?

    options = grouped_variants.sort_by { |label, _variants| label[/\d+(?:\.\d+)?/]&.to_d || Float::INFINITY }
      .first(8).map do |label, variants|
        prices = variants.map(&:price)
        price_label = prices.min == prices.max ? formatted_price(prices.min) :
          "#{formatted_price(prices.min)}–#{formatted_price(prices.max)}"
        examples = variants.map { |variant| variant.product.name }.uniq.first(2).to_sentence
        "• #{label} — #{price_label} (for example, #{examples})"
      end

    ([ "Our common available size options are:", *options, "", "Exact sizes depend on the product. Tell me a product name if you want its full size and price list." ]).join("\n")
  end

  def general_variant_request?
    customer_message&.content.to_s.downcase.squish.match?(
      /\b(general|overall|common|all products?|any product|jekono|যেকোনো)\b/
    )
  end

  def contextual_product
    return mentioned_product if mentioned_product.present?
    return pending_order.product if pending_order.product.present?

    remembered_name = pending_order.conversation.conversation_state.to_h["last_referenced_product"]
    catalog.find_by(name: remembered_name) if remembered_name.present?
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

  def combo_component_lines
    return [] unless pending_order.product&.combo?

    pending_order.product.combo_items.includes(:component_product).map do |item|
      "  ↳ Includes #{item.quantity} × #{item.component_product.name}"
    end
  end

  def address_suffix
    display = ConversationAddressPreference.display(address_preference)
    display.present? ? ", #{display}" : ""
  end
end
