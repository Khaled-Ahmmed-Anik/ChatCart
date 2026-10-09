class BotReplyGenerator
  def initialize(pending_order:, customer_message: nil, outcome: nil, interpretation: nil, address_preference: nil)
    @pending_order = pending_order
    @customer_message = customer_message
    @outcome = outcome&.to_sym
    @interpretation = interpretation
    @address_preference = address_preference
  end

  def content
    return cart_translation(:stock) if outcome == :cart_inventory_unavailable
    if outcome == :cart_needs_details
      return pending_order.conversation.conversation_state.to_h["cart_question"]
    end
    return cart_translation(:locked) if outcome == :cart_locked
    if outcome == :cart_updated
      return "#{cart_translation(:updated)}\n#{cart_lines.join("\n")}\n\n#{status_prompt}"
    end
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
      "Alhamdulillah, I’m doing well#{address_suffix} 😊 How can I help you today?"
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
    when :previous_question_explained
      previous_question_explanation
    when :price_inquiry
      product_information(:price)
    when :currency_clarification
      currency_reply
    when :stock_inquiry
      product_information(:stock)
    when :product_list_requested
      product_selection_prompt
    when :product_details_requested
      product_details_reply
    when :product_weather_requested
      product_weather_reply
    when :first_time_scent_guidance
      first_time_scent_reply
    when :recommendation_choice_reminder
      recommendation_choice_reminder
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
    when :discount_requested
      objection_policy_reply(policy.discount_policy, "I don’t have an approved discount to promise. Tell me your budget and I can show suitable lower-priced options.")
    when :authenticity_requested
      objection_policy_reply(policy.authenticity_statement, "I don’t have a verified authenticity statement configured, so I don’t want to make an unsupported claim. I can ask the seller to confirm it for you.")
    when :trust_information_requested
      objection_policy_reply(policy.trust_information, "I don’t have verified trust or review information configured yet. I can ask the seller to share the relevant details with you.")
    when :trial_requested
      objection_policy_reply(policy.trial_policy, "A trial or sample policy hasn’t been configured. If the product has a smaller in-stock size, I can show that option, or ask the seller to confirm.")
    when :delivery_price_objection
      delivery_price_objection_reply
    when :price_objection
      "I understand—you’d like a more affordable option.\n\n#{product_recommendation_reply}"
    when :return_requested
      after_sales_reply("return")
    when :return_policy_requested
      configured_policy("return policy", policy.return_policy || ENV["SHOP_RETURN_POLICY"])
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
      "Which size would you like? You can send the size, option number, or position—for example, “30 ML”, “3”, or “last one”.\n\n#{variant_selection_prompt}"
    when :variant_size_unavailable
      variant_bundle_offer_reply
    when :variant_options_rejected
      "No problem. What size are you looking for? If you need more than the largest bottle, tell me the amount—such as “50 ML” or “100 ML”—and I can check a multiple-bottle option."
    when :variant_bundle_selected
      "Great—#{pending_order.quantity} × #{pending_order.product_variant.display_name}. What name should I put on the order?"
    when :product_unavailable
      "Sorry, that product isn’t available right now. #{product_selection_prompt}"
    when :product_not_found
      "Are you asking about a product, recommendation, price, delivery, payment, or an existing order? You can send the product name, or tell me what you want and your budget."
    when :product_ambiguous
      product_ambiguity_reply
    when :invalid_quantity
      "How many would you like? You can send a number such as “2”, or write “two”."
    when :quantity_unavailable
      "We currently have #{selected_stock} available for that option. Would you like all #{selected_stock}, a smaller quantity, or should I ask the seller about a bulk order?"
    when :quantity_collected
      "Perfect—#{pending_order.quantity} #{bottle_word(pending_order.quantity)}. What name should I put on the order?"
    when :name_collected
      "Thanks, #{pending_order.customer_name}! What phone number should we use for the delivery?"
    when :name_required
      I18n.t("conversation_safety.#{banglish? ? 'banglish' : 'en'}.name_required")
    when :invalid_phone
      invalid_phone_reply
    when :phone_collected
      "Got it. What’s the full delivery address?"
    when :address_collected
      confirmation_prompt
    when :multiple_details_collected
      banglish? ? "Thik ache—selection save korechi. #{status_prompt}" : "Got it. #{status_prompt}"
    when :confirmation_unclear
      "Just to make sure, reply “confirm” to place the order or “cancel” to stop. You can also say something like “change quantity to 3”."
    when :confirmation_deferred
      "No problem—your order is saved, but it isn’t confirmed yet. Send “confirm” whenever you’re ready, or say “change the order” to update it."
    when :order_paused
      banglish? ? "Thik ache#{address_suffix}—eta ekhon pause rakhlam. Jokhon ichchhe notun kichu dekhte ba order korte bolben." :
        "No problem#{address_suffix}—I’ve paused that for now. Tell me whenever you want to explore something else or continue."
    when :order_updated
      "Done—I’ve updated it. #{status_prompt}"
    when :confirmed_order_updated
      "I’ve updated your confirmed order and reopened it for review. #{status_prompt}"
    when :order_change_requested
      order_change_help
    when :invalid_order_update
      "What would you like to change? #{order_change_help}"
    when :submitted_order_change_requested
      "That order has already been submitted for processing, so I can’t change it automatically. Please contact the seller for help."
    when :cancelled_order_change_requested
      "That order was cancelled, so it can’t be edited. Send “new order” to start again."
    when :confirmed
      "Thanks! Your order is confirmed ✅ We’ll send it for processing shortly. Was this chat helpful? Reply “helpful” or “not helpful”."
    when :cancelled
      "Your order has been cancelled. If you change your mind, just send “new order”."
    end
  end

  def status_prompt
    return banglish_status_prompt if banglish?

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

  def banglish_status_prompt
    case pending_order.status
    when "collecting_product" then "Kon product-ta nite chan? Product-er naam ba apnar preference bolun."
    when "collecting_variant" then "#{pending_order.product.name}-er kon size-ta niben?"
    when "collecting_quantity" then "Koyta niben?"
    when "collecting_name" then "Order-ta kon name-e dibo?"
    when "collecting_phone" then "Delivery-r jonno phone number-ta diben?"
    when "collecting_address" then "Full delivery address-ta diben?"
    when "awaiting_confirmation" then confirmation_prompt
    when "confirmed" then "Apnar order already confirmed ✅"
    else "Kibhabe help korte pari?"
    end
  end

  def product_selection_prompt
    products = available_products
    return "What product would you like to order?" if products.empty?

    remember_options!(:products, products)

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
    remember_options!(:products, visible_products)
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

    remember_options!(:variants, variants, product: pending_order.product)

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

  def variant_bundle_offer_reply
    offer = pending_order.conversation.conversation_state.to_h["variant_bundle_offer"].to_h
    return variant_selection_prompt if offer.blank?

    requested_sizes = Array(offer["requested_sizes"]).presence || [ offer["requested_size"] ]
    requested = requested_sizes.map { |size| formatted_size(size) }.to_sentence
    unit = formatted_size(offer["unit_size"])
    total = formatted_size(offer["total_size"])
    quantity = offer["quantity"].to_i
    price = formatted_price(offer["total_price"])
    comparison = total == requested ? requested : "#{total} in total"

    verb = requested_sizes.one? ? "isn’t" : "aren’t"
    "#{requested} #{verb} available as one bottle. Our largest available size is #{unit}. " \
      "You can take #{quantity} × #{unit} (#{comparison}) for #{price}. Would that work, or would you prefer another size?"
  end

  def formatted_size(value)
    number = value.to_d
    "#{number.frac.zero? ? number.to_i : number.to_s("F")} ML"
  end

  def variant_size_number(variant)
    variant.size.to_s[/\d+(?:\.\d+)?/]&.to_d || variant.position
  end

  def confirmation_prompt
    [
      "Here’s your order summary:",
      *cart_lines,
      "• Total: #{formatted_price(pending_order.total_price)}",
      "• Name: #{pending_order.customer_name}",
      "• Phone: #{pending_order.phone}",
      "• Address: #{pending_order.address}",
      "",
      "Does everything look right? Reply “confirm” to place it or “cancel” to stop."
    ].join("\n")
  end

  def cart_lines
    pending_order.line_items.flat_map do |item|
      [ "• #{item.quantity} × #{item.label} — #{formatted_price(item.total_price)}",
        *item.product.component_snapshot.map { |component| "  ↳ Includes #{component['quantity']} × #{component['name']}" } ]
    end
  end

  def cart_translation(key)
    I18n.t("#{banglish? ? 'cart_banglish' : 'cart'}.#{key}", locale: :en)
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
    orders = pending_order.conversation.pending_orders.where(status: [ :confirmed, :submitted_to_woocommerce ]).order(created_at: :desc, id: :desc).limit(3)
    return "You don’t have any previous orders yet." if orders.empty?

    lines = orders.map do |order|
      items = order.line_items.map { |item| "#{item.quantity} × #{item.label}" }.join(", ")
      "• Order ##{order.id}: #{items} — #{order.status.humanize}"
    end
    ([ "Here are your latest orders:" ] + lines).join("\n")
  end

  def product_details_reply
    product = contextual_product
    return product_selection_prompt if product.blank?

    return product_performance_reply(product) if performance_question?

    attributes = product.product_attributes.to_h
    families = Array(attributes["scent_families"]).first(4)
    notes = Array(attributes["notes"]).first(8)
    occasions = Array(attributes["occasions"]).first(4)
    variants = product.available_variants.to_a.sort_by { |variant| variant_size_number(variant) }

    lines = [ "#{product.name} starts from #{formatted_price(product.starting_price)}." ]
    summary = product.short_description.presence || product.description.to_s.squish.truncate(220)
    lines << summary if summary.present?
    lines << "Profile: #{families.to_sentence}." if families.any?
    lines << "Notes: #{notes.to_sentence}." if notes.any?
    lines << "Best for: #{occasions.to_sentence}." if occasions.any?
    performance = [
      attributes["longevity_hours"].presence&.then { |hours| "#{hours} hours longevity" },
      attributes["projection"].presence&.then { |projection| "#{projection} projection" }
    ].compact.to_sentence
    lines << "Performance: #{performance}." if performance.present?
    if variants.any?
      sizes = variants.map { |variant| "#{variant.display_name} #{formatted_price(variant.price)}" }
      lines << "Sizes: #{sizes.join(', ')}."
    end

    if product.combo?
      component_names = product.combo_items.includes(:component_product).map { |item| "#{item.quantity} × #{item.component_product.name}" }
      lines << "Includes: #{component_names.to_sentence}." if component_names.any?
    end
    lines << "Would you like a size recommendation or would you like to order it?"
    lines.join("\n")
  end

  def performance_question?
    customer_message&.content.to_s.downcase.match?(
      /\b(longevity|lasts?|long lasting|performance|projection|beshi khon|koto khon|kemon)\b|দীর্ঘস্থায়ী|কতক্ষণ/
    )
  end

  def product_performance_reply(product)
    attributes = product.product_attributes.to_h
    hours = attributes["longevity_hours"].presence
    projection = attributes["projection"].presence
    if interpretation&.language == "banglish"
      details = [ hours&.then { |value| "#{value} hours-er moto longevity" },
        projection&.then { |value| "#{value} projection" } ].compact.to_sentence
      return "#{product.name}-er #{details.presence || 'performance product ar use-er upor depend kore'}. Skin ar weather-er upor ektu vary korte pare."
    end

    details = [ hours&.then { |value| "around #{value} hours" },
      projection&.then { |value| "#{value} projection" } ].compact.to_sentence
    "#{product.name} offers #{details.presence || 'performance that varies by use'}. Performance can vary slightly with skin and weather."
  end

  def invalid_phone_reply
    saved = []
    saved << "name" if pending_order.customer_name.present?
    saved << "address" if pending_order.address.present?
    prefix = saved.any? ? "Saved so far: #{saved.to_sentence}. " : ""
    "#{prefix}Please send a complete Bangladesh phone number, for example 01712345678."
  end

  def product_recommendation_reply
    conversation_state = pending_order.conversation.conversation_state.to_h
    guided_context = conversation_state.dig("guided_sales", "context").to_h
    preferences = conversation_state["shopping_preferences"].to_h.merge(
      "rejected_product_ids" => guided_context["rejected_product_ids"],
      "previous_recommendations" => guided_context["last_recommendations"].presence ||
        conversation_state.dig("shopping_preferences", "previous_recommendations")
    )
    requested_count = preferences["recommendation_count"].to_i
    recommendation_count = requested_count.positive? ? requested_count.clamp(1, 3) : 3
    result = ProductRecommendationService.new(
      business: pending_order.conversation.business,
      message: customer_message&.content,
      preferences: preferences,
      limit: recommendation_count
    ).call
    return result.clarification_question if result.clarification_question.present?

    if result.offers.empty?
      return "Options in that range aren’t available right now. Our available prices start from #{formatted_price(result.minimum_price)}." if result.minimum_price

      return "Sorry, no products are currently available."
    end

    previous_recommendations = Array(guided_context["last_recommendations"])
    recommendation_snapshots = result.offers.map { |offer| recommendation_snapshot(offer) }
    GuidedSalesConversation.new(pending_order.conversation).remember_recommendations!(
      result.offers.map { |offer| offer.product.id }, offers: recommendation_snapshots
    )
    remember_options!(:products, result.offers.map(&:product).uniq)

    options = result.offers.first(recommendation_count).map do |offer|
      description = offer.product.short_description.presence || offer.product.description.to_s
      summary = description.squish.truncate(100)
      detail_lines = []
      reason = recommendation_reason(offer, preferences)
      detail_lines << "  Why it fits: #{reason}." if reason.present?
      detail_lines << "  #{summary}" if reason.blank? && summary.present?
      tradeoff = recommendation_tradeoff(offer, previous_recommendations, result)
      detail_lines << "  #{tradeoff}" if tradeoff.present?
      detail_lines << "  Best option: #{offer.variant.display_name} for #{formatted_price(offer.price)}." if offer.variant.present?
      heading = if result.budget_detected
        "• #{offer.product.name} — #{formatted_price(offer.price)}"
      else
        "• #{offer.product.name} — starts from #{formatted_price(offer.product.starting_price)}"
      end
      "#{heading}\n#{detail_lines.join("\n")}"
    end
    introduction = if !result.exact_match && result.requested_maximum.present?
      "The closest available option to your #{formatted_price(result.requested_maximum)} budget is"
    elsif !result.exact_match && preferences["price_direction"].present?
      "The closest available #{preferences['price_direction']} options are"
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
    question = banglish? ? "Kontar dike apnar beshi pochondo?" : "Which one sounds closest to what you want?"
    ([ "#{introduction}:", *options, "", question ]).join("\n")
  end

  def currency_reply
    rate = pending_order.conversation.business.settings.to_h["usd_exchange_rate"].to_d
    product = contextual_product
    if rate.positive? && product.present?
      amount = pending_order.product_variant&.price || product.starting_price
      dollars = (amount.to_d / rate).round(2)
      return "#{product.name} starts from approximately $#{format('%.2f', dollars)} USD (using ৳#{rate.to_i}/USD). The final charged amount remains in BDT."
    end
    if rate.positive?
      return "Prices are charged in BDT. Tell me the product name and I can estimate USD using the configured ৳#{rate.to_i}/USD rate."
    end

    "Our listed prices are in Bangladeshi taka (BDT). An exchange rate hasn’t been configured, so I won’t guess a dollar amount."
  end

  def banglish?
    return true if interpretation&.language == "banglish"

    pending_order.conversation.conversation_state.to_h["preferred_language"] == "banglish"
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

  def recommendation_reason(offer, preferences)
    searchable = [ offer.product.name, offer.product.category, offer.product.tags, offer.product.short_description,
      offer.product.description, offer.product.suitable_for, offer.product.product_attributes.to_h.flatten.join(" ") ]
      .compact.join(" ").downcase
    reasons = []
    preferences["attributes"].to_h.each do |key, values|
      matches = Array(offer.product.product_attributes.to_h[key]) & Array(values)
      reasons << "#{matches.join(', ')} #{key.humanize.downcase} matches your preference" if matches.any?
    end
    Array(preferences["scent_families"]).each do |family|
      reasons << "matches your #{family} preference" if searchable.include?(family.to_s.downcase)
    end
    Array(preferences["occasions"]).each do |occasion|
      reasons << "suited to #{occasion}" if searchable.include?(occasion.to_s.downcase)
    end
    audience = preferences["audience"].to_s
    reasons << "fits your #{audience} request" if audience.present? && searchable.include?(audience.downcase)
    reasons.first(2).to_sentence.presence
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
    count = pending_order.conversation.messages.customer.order(id: :desc).limit(8).count do |message|
      intelligence = message.metadata.to_h["conversation_intelligence"].to_h
      intelligence["needs_clarification"] || intelligence["outcome"] == "clarification_needed"
    end
    if count >= 2
      return "Sorry, I’m still not understanding correctly. Reply with a number:\n1. Choose or find a product\n2. Continue or change an order\n3. Ask about delivery or payment\n4. Talk to the seller"
    end

    options = pending_order.conversation.conversation_state.to_h.dig("last_offered_options", "options")
    if Array(options).size.between?(2, 4)
      labels = options.each_with_index.map { |option, index| "#{index + 1}. #{option['label'] || option['name']}" }
      return ([ "Did you mean one of these?", *labels, "Or tell me what you want in a few words." ]).join("\n")
    end

    "I’m not fully sure what you’d like to do. Are you choosing a product, changing an order, or asking about delivery/payment?"
  end

  def previous_question_explanation
    previous = pending_order.conversation.messages.bot.order(id: :desc).first&.content.to_s
    if previous.match?(/single.*combo|perfume.*combo|fragrance.*combo/i)
      return "Ami jiggesh korechilam apni single perfume niben, naki koyekti fragrance-er combo niben. Chaile budget-o bolte paren." if banglish?

      return "I was asking whether you want one perfume or a combo containing several fragrances. You can also share your budget."
    end
    if previous.match?(/scent|shondho|price|pochondo|like/i)
      return "Ami jiggesh korechilam product-er scent, price, ba onno kono bishoy apnar pochondo hoyni kina. Na nite chaile kono problem nei." if banglish?

      return "I was asking whether the scent, price, or something else did not suit you. It is completely fine if you do not want it."
    end

    return "Ager proshno-ta clear hoyni bujhte perechi. Kon part-ta bojha jayni bolle ami aro shohoj kore bolbo." if banglish?

    "I understand that my previous question was unclear. Tell me which part was confusing and I’ll explain it more simply."
  end

  def recommendation_choice_reminder
    ids = Array(GuidedSalesConversation.new(pending_order.conversation).context["last_recommended_product_ids"])
    products = catalog.available_for_sale.where(id: ids).index_by(&:id)
    ordered = ids.filter_map { |id| products[id.to_i] }
    return product_recommendation_reply if ordered.empty?

    remember_options!(:products, ordered)
    choices = ordered.first(3).each_with_index.map do |product, index|
      "#{index + 1}. #{product.name} — from #{formatted_price(product.starting_price)}"
    end
    ([ "These are the Oud options I meant:", *choices, "Reply 1, 2, or 3—or tell me if you want a single perfume instead of a combo." ]).join("\n")
  end

  def product_weather_reply
    product = contextual_product
    return "Which product would you like weather guidance for?" if product.blank?

    attributes = product.product_attributes.to_h
    families = Array(attributes["scent_families"]).map(&:downcase)
    occasions = Array(attributes["occasions"]).map(&:downcase)
    warm = families.intersect?(%w[oud woody oriental warm spicy tobacco sweet])
    guidance = if warm
      "cool weather, evenings, or air-conditioned environments"
    elsif families.intersect?(%w[fresh citrus aquatic marine airy clean])
      "warm weather and daytime use"
    else
      "moderate weather and the occasions listed for it"
    end
    extra = occasions.any? ? " It is especially suited to #{occasions.first(3).to_sentence}." : ""
    if interpretation&.language == "banglish"
      banglish = warm ? "cool weather, evening, ba AC environment-e best" : "warm weather ar daytime use-er jonno bhalo"
      return "#{product.name} #{banglish}. Weather onujayi spray kom-beshi korte paren.#{extra}"
    end

    "#{product.name} works best in #{guidance}. Adjust the number of sprays for the temperature.#{extra}"
  end

  def first_time_scent_reply
    family = Constants::Fragrance::SCENT_FAMILIES.find do |_name, terms|
      terms.any? { |term| customer_message&.content.to_s.downcase.match?(/\b#{Regexp.escape(term)}\b/) }
    end&.first || "that scent style"
    "No problem—first time #{family} try korle softer option ba smallest available size diye start kora safer. Apni soft/subtle naki bold/strong direction prefer korben?"
  end

  def objection_policy_reply(configured_value, fallback)
    configured_value.presence || fallback
  end

  def delivery_price_objection_reply
    charges = policy.delivery_charges || ENV["SHOP_DELIVERY_CHARGES"]
    return "I understand the delivery charge is a concern. #{charges}" if charges.present?

    "I understand the delivery charge is a concern, but the charge details haven’t been configured. I can ask the seller to confirm them."
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
    product = contextual_product
    return product_selection_prompt if product.blank?

    information = if kind == :price
      if product.product_variants.any?
        variants = product.available_variants.to_a
        requested = variants.find do |variant|
          [ variant.display_name, variant.size, variant.name ].compact.any? do |label|
            customer_message&.content.to_s.downcase.gsub(/\s+/, "").include?(label.downcase.gsub(/\s+/, ""))
          end
        end
        selected = requested.present? ? [ requested ] : variants
        selected.map { |variant| "#{variant.display_name}: #{formatted_price(variant.price)}" }.to_sentence
      else
        "#{product.name} is #{formatted_price(product.price)} per bottle."
      end
    elsif product.total_available_stock.positive?
      "Yes, #{product.name} is available—we have #{product.total_available_stock} in stock across its options."
    else
      "Sorry, #{product.name} is currently out of stock."
    end

    follow_up = product.product_variants.any? ? "Would you like one of these sizes?" : "Would you like to order it?"
    "#{information} #{follow_up}"
  end

  def product_variants_reply
    return general_product_variants_reply if general_variant_request?

    product = contextual_product
    return "Sure—which product would you like the size options for? Just send me its name." if product.blank?

    variants = product.available_variants.to_a.sort_by { |variant| variant_size_number(variant) }
    if variants.empty?
      return "#{product.name} currently has one standard option at #{formatted_price(product.price)}. How many would you like?"
    end

    remember_options!(:variants, variants, product: product)

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

  def remember_options!(kind, records, product: nil)
    ConversationMemory.new(pending_order.conversation).remember_options!(
      kind: kind, records: records, product: product
    )
  end
end
