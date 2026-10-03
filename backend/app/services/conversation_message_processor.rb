class ConversationMessageProcessor
  attr_reader :outcome, :secondary_outcomes

  def initialize(message:, pending_order:, interpretation: nil)
    @message = message
    @pending_order = pending_order
    @content = message.content.to_s.strip
    @interpretation = interpretation
  end

  def process
    unless message.customer?
      @outcome = :ignored
      return pending_order
    end

    return pending_order if accept_variant_bundle_offer
    return pending_order if apply_action_plan
    return pending_order if handle_order_update_request
    return pending_order if collect_remembered_checkout_value
    return pending_order if collect_explicit_checkout_value
    return pending_order if select_exact_catalog_product
    return pending_order if handle_conversational_intent
    return pending_order if handle_ai_intent
    return pending_order if collect_checkout_bundle

    case pending_order.status
    when "collecting_product"
      collect_product
    when "collecting_quantity"
      collect_quantity
    when "collecting_variant"
      collect_variant
    when "collecting_name"
      collect_name
    when "collecting_phone"
      collect_phone
    when "collecting_address"
      collect_address
    when "awaiting_confirmation"
      collect_confirmation
    end

    apply_remaining_interpreted_details
    @outcome ||= :no_change
    pending_order
  ensure
    @secondary_outcomes = mapped_secondary_outcomes
  end

  private

  attr_reader :message, :pending_order, :content, :interpretation

  def apply_action_plan
    plan = ConversationActionPlanner.new(
      message: message,
      business: pending_order.conversation.business,
      current_product: pending_order.product
    ).call
    return false unless plan.actionable?

    product = plan.product || pending_order.product
    variant = plan.variant
    return false if product.blank?
    return false if product.available_variants.any? && variant.blank?

    inventory = variant || product
    if plan.quantity.present? && !inventory.available_for_quantity?(plan.quantity)
      @outcome = :quantity_unavailable
      return true
    end

    attributes = { product: product, product_variant: variant }
    attributes[:quantity] = plan.quantity if plan.quantity.present?
    checkout_details = trustworthy_planned_checkout_details
    attributes.merge!(checkout_details)
    attributes[:status] = next_planned_status(product, variant, plan.quantity, checkout_details)
    pending_order.update!(attributes)
    @planned_secondary_outcomes = plan.informational_outcomes
    @outcome = :multiple_details_collected
    true
  end

  def next_planned_status(product, variant, quantity, checkout_details = {})
    return :collecting_variant if product.available_variants.any? && variant.blank?
    return :collecting_quantity if quantity.blank?
    return :collecting_name if checkout_details[:customer_name].blank? && pending_order.customer_name.blank?
    return :collecting_phone if checkout_details[:phone].blank? && pending_order.phone.blank?
    return :collecting_address if checkout_details[:address].blank? && pending_order.address.blank?

    :awaiting_confirmation
  end

  def handle_ai_intent
    return false if interpretation.blank?

    if interpretation.needs_clarification || interpretation.intent == "unclear"
      @outcome = :clarification_needed
      return true
    end

    @outcome = Constants::Conversation::AI_OUTCOMES[interpretation.intent]
    remember_referenced_product! if outcome.in?([ :product_details_requested, :price_inquiry, :stock_inquiry,
      :product_variants_requested ])
    outcome.present?
  end

  def remember_referenced_product!
    product = product_resolution.product if product_resolution.matched?
    return if product.blank?

    conversation = pending_order.conversation
    state = conversation.conversation_state.to_h
    conversation.update!(conversation_state: state.merge("last_referenced_product" => product.name))
  end

  def mapped_secondary_outcomes
    planned = Array(@planned_secondary_outcomes)
    return planned if interpretation.blank? || interpretation.needs_clarification

    mapped = interpretation.secondary_intents.filter_map do |intent|
      next unless intent.in?(ConversationIntentRegistry.informational_intents)

      Constants::Conversation::AI_OUTCOMES[intent]
    end
    (planned + mapped).uniq - [ outcome ]
  end

  def collect_product
    product = matching_product
    if product.blank?
      @outcome = product_resolution.ambiguous? ? :product_ambiguous :
        (named_unavailable_product? ? :product_unavailable : :product_not_found)
      return
    end

    pending_order.product = product
    pending_order.product_variant = matching_variant(product)
    pending_order.status = pending_order.product_variants_required? && pending_order.product_variant.blank? ?
      :collecting_variant : :collecting_quantity
    pending_order.save!
    if pending_order.collecting_variant? && requested_variant_sizes.any? && prepare_variant_bundle_offer
      @outcome = :variant_size_unavailable
      return
    end
    @outcome = collect_quantity_from_product_selection ? :multiple_details_collected : :product_selected
  end

  def collect_variant
    variant = matching_variant(pending_order.product)
    if variant.blank?
      @outcome = prepare_variant_bundle_offer ? :variant_size_unavailable : :variant_not_found
      return
    end

    clear_variant_bundle_offer!
    pending_order.update!(product_variant: variant, status: :collecting_quantity)
    quantity = parse_quantity(content) if combined_variant_quantity?
    if quantity.present? && variant.available_for_quantity?(quantity)
      pending_order.update!(quantity: quantity, status: :collecting_name)
      @outcome = :multiple_details_collected
    else
      @outcome = :variant_selected
    end
  end

  def collect_quantity
    quantity = parsed_quantity
    if quantity.blank?
      @outcome = :invalid_quantity
      return
    end
    if selected_inventory.present? && !selected_inventory.available_for_quantity?(quantity)
      @outcome = :quantity_unavailable
      return
    end

    pending_order.quantity = quantity
    advance_after_collection(:collecting_name)
    @outcome = :quantity_collected
  end

  def collect_name
    name = interpreted_entity(:customer_name, for_intent: "provide_name") || remembered_value(:customer_name) || extracted_customer_name
    if name.blank? || non_name_reply?(name)
      @outcome = :name_required
      return
    end

    pending_order.customer_name = name
    advance_after_collection(:collecting_phone)
    @outcome = :name_collected
  end

  def collect_phone
    phone = valid_phone_candidate(
      interpreted_entity(:phone, for_intent: "provide_phone"), remembered_value(:phone), content
    )
    unless phone_number?(phone)
      @outcome = :invalid_phone
      return
    end

    pending_order.phone = phone
    advance_after_collection(:collecting_address)
    @outcome = :phone_collected
  end

  def collect_address
    address = interpreted_entity(:address, for_intent: "provide_address") || remembered_value(:address) || content
    return if address.blank?

    pending_order.address = address
    advance_after_collection(:awaiting_confirmation)
    @outcome = :address_collected
  end

  def collect_checkout_bundle
    return false unless pending_order.status.in?(%w[collecting_name collecting_phone collecting_address])

    details = checkout_bundle_details
    return false if details.blank?

    pending_order.customer_name ||= details[:customer_name]
    pending_order.address ||= details[:address]
    if details[:phone].present? && !phone_number?(details[:phone])
      pending_order.status = :collecting_phone
      pending_order.save!
      @outcome = :invalid_phone
      return true
    end

    pending_order.phone ||= details[:phone]
    pending_order.status = next_checkout_status
    pending_order.save!
    @outcome = :multiple_details_collected
    true
  end

  def checkout_bundle_details
    parts = content.split(",").map(&:strip).reject(&:blank?)
    return if parts.size < 2

    phone_index = parts.index { |part| part.gsub(/\D/, "").length >= 8 }
    return if phone_index.blank?

    details = {
      phone: clean_checkout_value(parts[phone_index], :phone),
      address: clean_checkout_value(parts[(phone_index + 1)..]&.join(", "), :address)
    }
    details[:customer_name] = clean_checkout_value(parts.first, :customer_name) if phone_index.positive?
    details.compact_blank
  end

  def clean_checkout_value(value, field)
    labels = {
      customer_name: /\A(?:name|naam)\s*[:=-]?\s*/i,
      phone: /\A(?:phone|mobile|number)\s*[:=-]?\s*/i,
      address: /\A(?:address|location|thikana)\s*[:=-]?\s*/i
    }
    value.to_s.sub(labels.fetch(field), "").strip.presence
  end

  def next_checkout_status
    return :collecting_name if pending_order.customer_name.blank?
    return :collecting_phone if pending_order.phone.blank?
    return :collecting_address if pending_order.address.blank?

    :awaiting_confirmation
  end

  def collect_confirmation
    if confirmation?
      pending_order.confirmed!
      @outcome = :confirmed
    elsif cancellation?
      pending_order.cancelled!
      @outcome = :cancelled
    else
      @outcome = :confirmation_unclear
    end
  end

  def handle_order_update_request
    return false unless order_change_request? || correction_command? || ai_change_intent?

    if variant_correction_request? && matching_variant(pending_order.product).blank? && prepare_variant_bundle_offer
      @outcome = :variant_size_unavailable
      return true
    end

    if pending_order.status.in?(%w[collecting_variant collecting_quantity collecting_name collecting_phone collecting_address])
      @outcome = if order_change_request?
        :order_change_requested
      elsif apply_correction
        :order_updated
      else
        :invalid_order_update
      end
      return true
    end

    return false unless pending_order.status.in?(%w[awaiting_confirmation confirmed submitted_to_woocommerce cancelled])

    was_confirmed = pending_order.confirmed?
    @outcome = if pending_order.submitted_to_woocommerce?
      :submitted_order_change_requested
    elsif pending_order.cancelled?
      :cancelled_order_change_requested
    elsif order_change_request? || confident_ai_intent?(%w[change_confirmed_order])
      :order_change_requested
    elsif apply_correction
      reopen_confirmed_order(was_confirmed)
    else
      :invalid_order_update
    end

    true
  end

  def reopen_confirmed_order(was_confirmed)
    return :order_updated unless was_confirmed

    pending_order.update!(status: :awaiting_confirmation) if pending_order.ready_for_confirmation?
    pending_order.order&.update!(status: "revision_pending")
    :confirmed_order_updated
  end

  def handle_conversational_intent
    @outcome = if repeat_order_request?
      repeat_previous_order ? :repeat_order_prepared : :restarted
    elsif restart_request?
      restart_order
      :restarted
    elsif defer_confirmation_request?
      :confirmation_deferred
    elsif resume_browsed_order_request?
      resume_browsed_order
    elsif variant_options_rejection?
      :variant_options_rejected
    elsif recommendation_rejection?
      reject_recommendations
    elsif shortlist_show_request?
      :shortlist_requested
    elsif shortlist_add_request?
      update_shortlist(:add)
    elsif shortlist_remove_request?
      update_shortlist(:remove)
    elsif order_details_request?
      :order_details_requested
    elsif product_list_request?
      :product_list_requested
    elsif product_variants_request? || product_variants_follow_up?
      :product_variants_requested
    elsif greeting?
      :greeting
    elsif weather_question?
      :product_weather_requested
    elsif first_time_scent_statement?
      :first_time_scent_guidance
    elsif repeated_recommendation_input?
      :recommendation_choice_reminder
    elsif return_policy_question?
      :return_policy_requested
    elsif discount_request?
      :discount_requested
    elsif authenticity_question?
      :authenticity_requested
    elsif trust_question?
      :trust_information_requested
    elsif trial_request?
      :trial_requested
    elsif delivery_price_objection?
      :delivery_price_objection
    elsif price_objection?
      prepare_lower_priced_recommendations!
      :price_objection
    elsif budget_recommendation_request?
      enter_product_discovery!
      remember_recommendation_preferences!
      :product_recommendation_requested
    elsif currency_question?
      :currency_clarification
    elsif price_question?
      :price_inquiry
    elsif stock_question?
      :stock_inquiry
    elsif comparison_request?
      :product_comparison_requested
    elsif recommendation_refinement_request?
      enter_product_discovery!
      remember_recommendation_preferences!
      :product_recommendation_requested
    elsif recommendation_request?
      enter_product_discovery!
      remember_recommendation_preferences!
      :product_recommendation_requested
    elsif help_request?
      :help
    elsif thanks?
      :thanks
    elsif human_agent_request?
      :human_agent
    end

    outcome.present?
  end

  def restart_order
    pending_order.update!(
      product: nil,
      product_variant: nil,
      quantity: nil,
      customer_name: nil,
      phone: nil,
      address: nil,
      status: :collecting_product
    )
    GuidedSalesConversation.new(pending_order.conversation).reset!
  end

  def repeat_previous_order
    previous = previous_completed_order
    inventory = previous&.product_variant || previous&.product
    unless inventory&.available_for_quantity?(previous.quantity)
      restart_order
      return false
    end

    pending_order.update!(
      product: previous.product,
      product_variant: previous.product_variant,
      quantity: previous.quantity,
      customer_name: previous.customer_name,
      phone: previous.phone,
      address: previous.address,
      status: :awaiting_confirmation
    )
    true
  end

  def apply_correction
    return update_variant_from_content if variant_correction_request?
    return update_product_from_content if product_correction_request?
    return apply_ai_correction if ai_change_intent?

    case content
    when /\A(?:actually[\s,]*)?(?:change|update)\s+(?:the\s+)?quantity\s+(?:to\s+)?(.+)\z/i,
      /\A(?:actually[\s,]*)?make\s+it\s+(.+)\z/i,
      /\A(.+?)\s+(?:ta|টা)?\s*(?:koren|করেন|hobe|হবে)\z/i
      update_quantity(Regexp.last_match(1))
    when /\A(?:actually[\s,]*)?(?:change|update)\s+(?:my\s+)?phone\s+(?:number\s+)?(?:to\s+)?(.+)\z/i
      update_phone(Regexp.last_match(1))
    when /\A(?:actually[\s,]*)?(?:change|update)\s+(?:my\s+)?name\s+(?:to\s+)?(.+)\z/i,
      /\A(?:my\s+name\s+is|amar\s+naam|amar\s+nam|name|naam)\s+(.+?)(?:\s+(?:update|change)(?:\s+(?:it\s+)?(?:on|in))?\s+(?:my\s+|the\s+)?order)?[?!. ]*\z/i
      record_change(:customer_name, Regexp.last_match(1).strip)
    when /\A(?:actually[\s,]*)?(?:change|update)\s+(?:the\s+)?address\s+(?:to\s+)?(.+)\z/i,
      /\A(?:actually[\s,]*)?address(?:\s+ta)?\s+(.+?)\s+(?:hobe|হবে)\z/i
      record_change(:address, Regexp.last_match(1).strip)
    else
      false
    end
  end

  def apply_ai_correction
    case interpretation.intent
    when "change_quantity"
      update_quantity(interpretation.entities[:quantity].presence || content)
    when "change_phone"
      update_phone(valid_phone_candidate(interpretation.entities[:phone], content).to_s)
    when "change_name"
      record_change(:customer_name, interpretation.entities[:customer_name].to_s.strip)
    when "change_address"
      record_change(:address, interpretation.entities[:address].to_s.strip)
    when "change_product"
      update_product(interpretation.entities[:product_name].to_s)
    else
      false
    end
  end

  def update_product(name)
    resolution = ProductResolutionService.new(business: pending_order.conversation.business, query: name).resolve
    product = resolution.product
    return false unless resolution.matched?

    update_product_record(product)
  end

  def update_product_from_content
    normalized = content.downcase
    matches = catalog.available_for_sale.select do |product|
      product.searchable_names.any? { |name| normalized.include?(name.downcase) }
    end
    product = matches.last
    return false if product.blank? || product == pending_order.product

    update_product_record(product)
  end

  def update_product_record(product)
    previous_product = pending_order.product
    history = pending_order.change_history.dup
    history << {
      "field" => "product",
      "from" => previous_product&.name,
      "to" => product.name,
      "changed_at" => Time.current.iso8601,
      "message_id" => message.id
    }
    pending_order.update!(
      product: product, product_variant: nil, quantity: nil,
      status: product.product_variants.any? ? :collecting_variant : :collecting_quantity,
      change_history: history
    )
    true
  end

  def update_variant_from_content
    product = pending_order.product
    return false if product.blank? || product.product_variants.empty?

    variant = previous_offered_variant(product) || matching_variant(product)
    return false if variant.blank? || variant == pending_order.product_variant

    previous_variant = pending_order.product_variant
    quantity = pending_order.quantity
    quantity = nil unless variant.available_for_quantity?(quantity)
    history = pending_order.change_history.dup
    history << {
      "field" => "product_variant",
      "from" => previous_variant&.display_name,
      "to" => variant.display_name,
      "changed_at" => Time.current.iso8601,
      "message_id" => message.id
    }
    pending_order.update!(
      product_variant: variant,
      quantity: quantity,
      status: next_status_after_selection(quantity: quantity),
      change_history: history
    )
    true
  end

  def previous_offered_variant(product)
    return unless content.downcase.match?(/\b(previous|one before|ager|agerta|আগের)\b/)

    variants = offered_variants_for(product)
    current_index = variants.index(pending_order.product_variant)
    return if current_index.blank? || current_index.zero?

    variants[current_index - 1]
  end

  def next_status_after_selection(quantity: pending_order.quantity)
    return :collecting_quantity if quantity.blank?
    return :collecting_name if pending_order.customer_name.blank?
    return :collecting_phone if pending_order.phone.blank?
    return :collecting_address if pending_order.address.blank?

    :awaiting_confirmation
  end

  def update_quantity(value)
    quantity = parse_quantity(value)
    return false if quantity.blank? || selected_inventory.blank? || !selected_inventory.available_for_quantity?(quantity)

    record_change(:quantity, quantity)
  end

  def update_phone(value)
    phone = valid_phone_candidate(value, content).to_s
    return false unless phone_number?(phone)

    record_change(:phone, phone)
  end

  def record_change(field, new_value)
    return false if new_value.blank?

    previous_value = pending_order.public_send(field)
    return true if previous_value.to_s == new_value.to_s

    history = pending_order.change_history.dup
    history << {
      "field" => field.to_s,
      "from" => previous_value&.to_s,
      "to" => new_value.to_s,
      "changed_at" => Time.current.iso8601,
      "message_id" => message.id
    }
    pending_order.update!(field => new_value, change_history: history)
    true
  end

  def apply_remaining_interpreted_details
    return if interpretation.blank? || interpretation.needs_clarification

    collected = 0
    loop do
      advanced = case pending_order.status
      when "collecting_quantity"
        collect_interpreted_quantity
      when "collecting_name"
        collect_interpreted_value(:customer_name, :collecting_phone)
      when "collecting_phone"
        collect_interpreted_phone
      when "collecting_address"
        collect_interpreted_value(:address, :awaiting_confirmation)
      else
        false
      end
      break unless advanced

      collected += 1
    end

    @outcome = :multiple_details_collected if collected.positive?
  end

  def collect_interpreted_quantity
    quantity = interpretation.entities[:quantity].to_i
    return false unless quantity.positive? && selected_inventory&.available_for_quantity?(quantity)

    pending_order.update!(quantity: quantity, status: :collecting_name)
    true
  end

  def collect_interpreted_value(field, next_status)
    value = interpretation.entities[field].to_s.strip
    return false if value.blank?

    pending_order.update!(field => value, status: next_status)
    true
  end

  def collect_interpreted_phone
    phone = valid_phone_candidate(interpretation.entities[:phone], content).to_s
    return false unless phone_number?(phone)

    pending_order.update!(phone: phone, status: :collecting_address)
    true
  end

  def advance_after_collection(next_status)
    pending_order.status = pending_order.ready_for_confirmation? ? :awaiting_confirmation : next_status
    pending_order.save!
  end

  def matching_product
    contextual_product_selection || (product_resolution.product if product_resolution.matched?)
  end

  def contextual_product_selection
    normalized = content.downcase.squish
    if normalized.match?(/\b(previous product|previous one|one before|ager product|agerta|আগের প্রোডাক্ট|আগেরটা)\b/)
      history = Array(pending_order.conversation.conversation_state.to_h.dig("turn_manager", "reference_history"))
      current_id = pending_order.product_id || history.last&.dig("product_id")
      previous = history.reverse.find { |reference| reference["product_id"].to_i != current_id.to_i }
      product = catalog.available_for_sale.find_by(id: previous&.dig("product_id"))
      return product if product.present?
    end

    offered = last_offered_options
    if offered["kind"] == "products"
      offered_ids = Array(offered["options"]).filter_map { |option| option["id"] }
      position = option_position(normalized, offered_ids.length, exact_numeric: true)
      if position.present? && offered_ids[position].present?
        return catalog.available_for_sale.find_by(id: offered_ids[position])
      end
    end

    flow_context = GuidedSalesConversation.new(pending_order.conversation).context
    recommended_ids = Array(flow_context["last_recommended_product_ids"])
    shortlisted_ids = Array(flow_context["shortlist_product_ids"])
    ids = recommended_ids.presence || shortlisted_ids
    return if ids.blank?

    position = option_position(normalized, ids.length)
    position = 0 if position.blank? && normalized.match?(
      /\A(eta|eita|this one|this|এটা)( nibo| chai| please)?[?!. ]*\z/
    ) && ids.one?
    return if position.blank? || ids[position].blank?

    catalog.available_for_sale.find_by(id: ids[position])
  end

  def product_resolution
    turn_reference = pending_order.conversation.conversation_state.to_h.dig("turn_manager", "reference", "product_name")
    @product_resolution ||= ProductResolutionService.new(
      business: pending_order.conversation.business,
      query: interpreted_entity(:product_name, for_intent: "select_product") || content,
      recent_product_name: turn_reference.presence ||
        pending_order.conversation.conversation_state.to_h["last_referenced_product"]
    ).resolve
  end

  def matching_variant(product)
    return if product.blank? || product.product_variants.none?

    requested = interpretation&.entities&.values_at(:variant_name, :size)&.find(&:present?)
    exact = product.available_variants.find do |variant|
      candidates = [ variant.name, variant.size ].compact.map(&:downcase)
      !variant_explicitly_rejected?(variant) && (candidates.include?(requested.to_s.downcase) || candidates.any? { |candidate|
        content.downcase.include?(candidate) || content.downcase.delete(" ").include?(candidate.delete(" "))
      } ||
        content.match?(/\b#{Regexp.escape(variant.price.to_i.to_s)}\b/))
    end
    exact || contextual_variant_selection(product)
  end

  def variant_explicitly_rejected?(variant)
    labels = [ variant.name, variant.size ].compact.map { |value| Regexp.escape(value.downcase).gsub("\\ ", "\\s*") }
    labels.any? { |label| content.downcase.match?(/\b#{label}\b\s*(?:na|no|not|না)\b/) }
  end

  def contextual_variant_selection(product)
    variants = offered_variants_for(product)
    variants = product.available_variants.to_a.sort_by { |variant| variant_size_number(variant) } if variants.empty?
    return if variants.empty?

    normalized = content.downcase.squish
    position = option_position(normalized, variants.length, exact_numeric: true)
    return variants[position] if position.present? && variants[position].present?

    return variants.first if normalized.match?(/\b(small|smallest|choto|trial|try)\b/)
    if normalized.match?(/\b(bigger|larger|next size|aro boro|আরও বড়)\b/)
      current_size = variant_size_number(pending_order.product_variant) if pending_order.product_variant
      return variants.find { |variant| variant_size_number(variant) > current_size } if current_size
      return variants.last
    end
    return variants.last if normalized.match?(/\b(large|largest|boro|big|best val(?:ue)?|regular use)\b/)
    variants[variants.length / 2] if normalized.match?(/\b(medium|middle|majhari)\b/)
  end

  def prepare_variant_bundle_offer
    product = pending_order.product
    variants = product&.available_variants.to_a.sort_by { |variant| variant_size_number(variant) }
    return false if variants.blank?

    largest = variants.last
    largest_size = variant_size_number(largest)
    requested_sizes = requested_variant_sizes
    requested_size = requested_sizes.first
    if requested_size.blank? && relative_larger_variant_request? && pending_order.product_variant == largest
      requested_size = largest_size * 2
    end
    return false if requested_size.blank? || requested_size <= largest_size

    quantity = (requested_size / largest_size).ceil
    return false unless largest.available_for_quantity?(quantity)

    state = pending_order.conversation.conversation_state.to_h
    state["variant_bundle_offer"] = {
      "product_id" => product.id,
      "variant_id" => largest.id,
      "requested_size" => requested_size.to_s("F"),
      "requested_sizes" => requested_sizes.map { |size| size.to_s("F") },
      "unit_size" => largest_size.to_s("F"),
      "quantity" => quantity,
      "total_size" => (largest_size * quantity).to_s("F"),
      "total_price" => (largest.price * quantity).to_s
    }
    pending_order.conversation.update!(conversation_state: state)
    true
  end

  def accept_variant_bundle_offer
    offer = pending_order.conversation.conversation_state.to_h["variant_bundle_offer"].to_h
    return false if offer.blank? || !content.downcase.squish.match?(/\A(yes|okay|ok|sure|that works|nibo|den|হ্যাঁ|ঠিক আছে)[?!. ]*\z/)
    return false unless offer["product_id"].to_i == pending_order.product_id

    variant = pending_order.product.available_variants.find_by(id: offer["variant_id"])
    quantity = offer["quantity"].to_i
    return false unless variant&.available_for_quantity?(quantity)

    pending_order.update!(product_variant: variant, quantity: quantity, status: :collecting_name)
    clear_variant_bundle_offer!
    @outcome = :variant_bundle_selected
    true
  end

  def clear_variant_bundle_offer!
    state = pending_order.conversation.conversation_state.to_h
    return unless state.key?("variant_bundle_offer")

    pending_order.conversation.update!(conversation_state: state.except("variant_bundle_offer"))
  end

  def requested_variant_size
    requested_variant_sizes.first
  end

  def requested_variant_sizes
    normalized = content.tr("০১২৩৪৫৬৭৮৯", "0123456789")
    values = normalized.scan(/(\d+(?:\.\d+)?)\s*(?:ml|মিলি)/i).flatten
    if normalized.match?(/\b(?:or|ba)\b|অথবা/) && normalized.match?(/(?:ml|মিলি)/i)
      values = normalized.scan(/\d+(?:\.\d+)?/)
    end
    values.map(&:to_d).uniq
  end

  def combined_variant_quantity?
    normalized = content.tr("০১২৩৪৫৬৭৮৯", "0123456789").downcase
    without_size = normalized.sub(/\b\d+(?:\.\d+)?\s*(?:ml|মিলি)\b/, " ")
    normalized.match?(/\b\d+(?:\.\d+)?\s*(?:ml|মিলি)\b/) &&
      without_size.match?(/\b(?:\d+|one|two|three|four|five|ekta|duita|duta|tinta)\b/)
  end

  def relative_larger_variant_request?
    content.downcase.match?(/\b(bigger|larger|next size|aro boro|boro size)\b|আরও বড়|বড় সাইজ/)
  end

  def offered_variants_for(product)
    offered = last_offered_options
    return [] unless offered["kind"] == "variants" && offered["product_id"].to_i == product.id

    variants_by_id = product.available_variants.index_by(&:id)
    Array(offered["options"]).filter_map { |option| variants_by_id[option["id"].to_i] }
  end

  def last_offered_options
    pending_order.conversation.conversation_state.to_h["last_offered_options"].to_h
  end

  def option_position(normalized, option_count, exact_numeric: false)
    return 0 if normalized.match?(/\b(first|1st|prothom)\b/) ||
      (exact_numeric && normalized.match?(/\A(?:1|one)[?!. ]*\z/))
    return 1 if normalized.match?(/\b(second|2nd|ditiyo)\b/) ||
      (exact_numeric && normalized.match?(/\A(?:2|two)[?!. ]*\z/))
    return 2 if normalized.match?(/\b(third|3rd|tritiyo)\b/) ||
      (exact_numeric && normalized.match?(/\A(?:3|three)[?!. ]*\z/))
    return option_count - 1 if normalized.match?(/\b(last|last one|shesh|শেষ)\b/)

    nil
  end

  def variant_size_number(variant)
    variant.size.to_s[/\d+(?:\.\d+)?/]&.to_d || variant.position
  end

  def selected_inventory
    pending_order.product_variant || pending_order.product
  end

  def named_unavailable_product?
    catalog.find_each.any? { |product| content.downcase.include?(product.name.downcase) }
  end

  def catalog
    pending_order.conversation.business.products
  end

  def parsed_quantity
    ai_quantity = interpretation&.entities&.[](:quantity).to_i
    return ai_quantity if interpretation&.intent == "select_quantity" && ai_quantity.positive?

    parse_quantity(content)
  end

  def parse_quantity(value)
    normalized = value.to_s.downcase
      .gsub(/\b(first|second|third|last|prothom|ditiyo|tritiyo)\s+one\b/, "")
      .gsub(/\b\d+(?:\.\d+)?\s*ml\b/, "")

    word_quantity = Constants::Conversation::NUMBER_WORDS.find do |word, _number|
      normalized.match?(/\b#{word}\b/)
    end&.last
    return word_quantity if word_quantity.present?

    numeric_quantity = normalized[/\d+/]&.to_i
    numeric_quantity if numeric_quantity&.positive?
  end

  def collect_quantity_from_product_selection
    return false unless pending_order.collecting_quantity?
    return false if last_offered_options["kind"] == "products" && content.match?(/\A\s*\d+\s*[?!.]*\z/)

    quantity = parsed_quantity
    return false if quantity.blank? || !selected_inventory&.available_for_quantity?(quantity)

    pending_order.quantity = quantity
    advance_after_collection(:collecting_name)
    true
  end

  def phone_number?(value = content)
    digits = value.to_s.gsub(/\D/, "")
    digits.match?(/\A01[3-9]\d{8}\z/) || digits.match?(/\A8801[3-9]\d{8}\z/)
  end

  def valid_phone_candidate(*values)
    value = values.compact.map(&:to_s).find { |candidate| phone_number?(candidate) }
    return if value.blank?

    stripped = value.strip
    return stripped if stripped.match?(/\A\+?\d+\z/)

    stripped.gsub(/\D/, "").presence
  end

  def confirmation?
    normalized_content.in?(%w[confirm confirmed yes y]) || confident_ai_intent?(%w[confirm_order])
  end

  def cancellation?
    normalized_content.in?(%w[cancel cancelled stop no n]) || confident_ai_intent?(%w[cancel_order])
  end

  def normalized_content
    content.downcase.gsub(/[^a-z]/, "")
  end

  def greeting?
    normalized = content.downcase.strip
    normalized.match?(/\A(hi|hello|hey|assalamu?\s*alaikum|assalamu?laikum|assalamulaikum|salam)[!. ]*\z/) ||
      normalized.match?(/\A(it'?s|this is)\s+(a\s+)?greeting[s]?[!. ]*\z/)
  end

  def help_request?
    content.downcase.match?(/\b(help|menu)\b/)
  end

  def product_variants_request?
    normalized = content.downcase.squish
    normalized.match?(/\b(size|sizes|variant|variants)\b.*\b(option|options|available|have|ache|ki|what|which)\b/) ||
      normalized.match?(/\b(what|which|available|ki ki)\b.*\b(size|sizes|variant|variants)\b/) ||
      normalized.match?(/\A(size|sizes|size options|variant|variants)[?!. ]*\z/)
  end

  def product_variants_follow_up?
    return false unless pending_order.conversation.conversation_state.to_h["last_outcome"] == "product_variants_requested"

    normalized = content.downcase.squish
    generic_reply = normalized.match?(/\A(any( product)?|general|overall|common|all|doesn'?t matter|jekono|যেকোনো)[?!. ]*\z/)
    generic_reply || product_resolution.matched?
  end

  def product_list_request?
    normalized = content.downcase.squish
    normalized.match?(/\b(show|see|list)\s+(me\s+)?(all\s+)?products?a?\b/) ||
      normalized.match?(/\b(available|all)\s+products?a?\b/) ||
      normalized.match?(/\b(products?a?)\s+(dekhao|dekhaw|list)\b/) ||
      normalized.match?(/ki ki product|product ki ki/)
  end

  def thanks?
    content.downcase.strip.match?(/\A(thanks|thank you|thx)[!. ]*\z/)
  end

  def restart_request?
    intent_detector.new_order? || confident_ai_intent?(%w[new_order repeat_order])
  end

  def repeat_order_request?
    confident_ai_intent?(%w[repeat_order]) ||
      content.downcase.match?(/\b(re-?order|order again|same order|ager order|আগের অর্ডার)\b/)
  end

  def order_details_request?
    intent_detector.order_details? || confident_ai_intent?(%w[order_details review_order order_status])
  end

  def price_question?
    content.downcase.match?(/\b(price|cost)\b|how much/)
  end

  def currency_question?
    content.downcase.match?(/\b(dollar|doller|usd|currency|taka|bdt)\b|ডলার|টাকা/) &&
      !content.downcase.match?(/\b(price|cost|budget|under|within)\b/)
  end

  def discount_request?
    content.downcase.match?(/\b(discount|offer|best price|last price|komaben|kom hobe|ছাড়|কমাবেন)\b/)
  end

  def authenticity_question?
    content.downcase.match?(/\b(original|authentic|genuine|real product|fake)\b|অরিজিনাল|আসল|নকল/)
  end

  def trust_question?
    content.downcase.match?(/\b(trust|trusted|reliable|scam|proof|review)\b|বিশ্বাস|ভরসা/)
  end

  def trial_request?
    normalized = content.downcase
    normalized.match?(/\b(trial|sample|tester|test first)\b|স্যাম্পল|ট্রায়াল/) ||
      normalized.match?(/\b(can|could|may)\s+i\s+try\b|\btry\s+(before|first)\b/)
  end

  def weather_question?
    content.downcase.match?(/\b(weather|season|summer|winter|gorom|thanda)\b|আবহাওয়া|গরম|শীত/)
  end

  def first_time_scent_statement?
    normalized = content.downcase
    normalized.match?(/\b(never|haven'?t|have not|try kori nai|use kori nai|kokhono.*nai)\b/) &&
      Constants::Fragrance::SCENT_FAMILIES.values.flatten.any? { |term| normalized.match?(/\b#{Regexp.escape(term)}\b/) }
  end

  def repeated_recommendation_input?
    return false unless pending_order.conversation.conversation_state.to_h["last_outcome"] == "product_recommendation_requested"

    previous = pending_order.conversation.messages.customer.where.not(id: message.id).order(id: :desc).first
    previous.present? && previous.content.to_s.downcase.squish == content.downcase.squish
  end

  def delivery_price_objection?
    normalized = content.downcase
    normalized.match?(/\b(delivery|shipping)\b/) && normalized.match?(/\b(expensive|high|too much|free|kom|reduce)\b|বেশি|কম/)
  end

  def price_objection?
    content.downcase.match?(/\b(too expensive|expensive|costly|dam beshi|onek dam)\b|দাম বেশি/)
  end

  def prepare_lower_priced_recommendations!
    baseline = pending_order.unit_price if pending_order.product.present?
    enter_product_discovery!
    conversation = pending_order.conversation
    state = conversation.conversation_state.to_h
    preferences = state["shopping_preferences"].to_h.merge("price_direction" => "lower")
    preferences["previous_recommendations"] = [ { "price" => baseline.to_s } ] if baseline.present?
    state["shopping_preferences"] = preferences
    conversation.update!(conversation_state: state)
  end

  def budget_recommendation_request?
    normalized = content.downcase.tr("০১২৩৪৫৬৭৮৯", "0123456789")
    normalized.match?(/\b(under|below|within|budget|cheapest|lowest|starting price|price starts|kom dam|moddhe)\b|মধ্যে|নিচে|বাজেট|কম দাম/)
  end

  def recommendation_request?
    return true if budget_recommendation_request?
    return true if discovery_follow_up?
    return true if active_discovery_preference?
    return false if product_resolution.matched?

    content.downcase.match?(
      /\b(suggest|recommend|help me choose|(?:give|show)(?:\s+me)?(?:\s+some)?\s+options?|which (perfume|fragrance)|(?:want|need|looking for)(?:\s+\w+){0,3}\s+(?:perfume|fragrance)|combo|bundle|single(?: perfume)?|one perfume)\b|\b(fresh|sweet|fruity|floral|woody|oud|spicy|tobacco)\b.*\b(perfume|fragrance|scent|kichu)\b|\b(oudy|oudi|oody|oddy|ody)\b/
    )
  end

  def active_discovery_preference?
    return false unless GuidedSalesConversation.new(pending_order.conversation).stage == "discover"

    extracted = FragrancePreferenceExtractor.new(content).call
    extracted.values_at("format", "audience", "performance", "scent_families", "occasions").any?(&:present?)
  end

  def discovery_follow_up?
    preferences = pending_order.conversation.conversation_state.to_h["shopping_preferences"]
    return false unless content.downcase.squish.match?(/\A(ekta|ekta nibo|one|single|combo|একটা)[?!. ]*\z/)
    return true if preferences.present?

    pending_order.conversation.messages.bot.order(created_at: :desc, id: :desc).limit(5).any? do |recent_message|
      recent_message.content.downcase.match?(/single.*combo|one perfume.*combo|ekta perfume.*combo/)
    end
  end

  def enter_product_discovery!
    flow = GuidedSalesConversation.new(pending_order.conversation)
    flow.suspend_order!(pending_order)
    flow.transition!("discover") unless flow.stage == "discover"
    return unless pending_order.status.in?(%w[
      collecting_variant collecting_quantity collecting_name collecting_phone collecting_address awaiting_confirmation
    ])

    pending_order.update!(product: nil, product_variant: nil, quantity: nil, status: :collecting_product)
  end

  def remember_recommendation_preferences!
    conversation = pending_order.conversation
    state = conversation.conversation_state.to_h
    state["shopping_preferences"] = FragrancePreferenceExtractor.new(content).call(
      existing: state["shopping_preferences"]
    )
    conversation.update!(conversation_state: state)
  end

  def resume_browsed_order_request?
    content.downcase.match?(/\b(continue|resume|back to)\b.*\b(order|checkout)\b|\border\s+(continue|resume)\b/) ||
      confident_ai_intent?(%w[resume_order go_back])
  end

  def resume_browsed_order
    restored = GuidedSalesConversation.new(pending_order.conversation).resume_order!(pending_order)
    restored ? :resume_order_requested : :order_details_requested
  end

  def recommendation_rejection?
    return false unless GuidedSalesConversation.new(pending_order.conversation).stage.in?(%w[discover compare])

    confident_ai_intent?(%w[reject_recommendations]) ||
      content.downcase.match?(/don'?t like (these|them|any)|not these|none( of these)?|no one|not any|show (me )?different|kono ta na|egula pochondo (hoy )?nai|এগুলো.*পছন্দ.*না/)
  end

  def variant_options_rejection?
    pending_order.collecting_variant? && content.downcase.squish.match?(
      /\A(no|none|none of these|egula na|kono ta na|না|কোনোটাই না)[?!. ]*\z/
    )
  end

  def reject_recommendations
    flow = GuidedSalesConversation.new(pending_order.conversation)
    rejected_ids = flow.reject_last_recommendations!
    state = pending_order.conversation.conversation_state.to_h
    extractor = FragrancePreferenceExtractor.new(content)
    preferences = extractor.call(existing: state.fetch("shopping_preferences", {}))
      .merge("rejected_product_ids" => rejected_ids)
    pending_order.conversation.update!(conversation_state: state.merge("shopping_preferences" => preferences))
    extractor.meaningful? ? :product_recommendation_requested : :recommendations_rejected
  end

  def shortlist_show_request?
    confident_ai_intent?(%w[shortlist_show]) ||
      content.downcase.match?(/\b(show|view|my)\b.*\b(shortlist|saved|choices)\b|\bshortlist\b/)
  end

  def shortlist_add_request?
    confident_ai_intent?(%w[shortlist_add]) ||
      content.downcase.match?(/\b(keep|save|shortlist|remember)\b.*\b(first|second|third|one|ones|option|product|these|this)\b/)
  end

  def shortlist_remove_request?
    confident_ai_intent?(%w[shortlist_remove]) || content.downcase.match?(/\b(remove|drop|bad dao|বাদ দাও)\b/)
  end

  def update_shortlist(action)
    ids = referenced_recommendation_ids
    flow = GuidedSalesConversation.new(pending_order.conversation)
    action == :add ? flow.add_to_shortlist!(ids) : flow.remove_from_shortlist!(ids)
    :shortlist_updated
  end

  def referenced_recommendation_ids
    flow = GuidedSalesConversation.new(pending_order.conversation)
    recommended = Array(flow.context["last_recommended_product_ids"])
    normalized = content.downcase
    return [ recommended[0] ].compact if normalized.match?(/\b(first|1st|prothom)\b/)
    return [ recommended[1] ].compact if normalized.match?(/\b(second|2nd|ditiyo)\b/)
    return [ recommended[2] ].compact if normalized.match?(/\b(third|3rd|tritiyo)\b/)

    named = catalog.select { |product| product.searchable_names.any? { |name| normalized.include?(name.downcase) } }.map(&:id)
    named.presence || recommended
  end

  def stock_question?
    content.downcase.match?(/\b(stock|available|availability)\b/)
  end

  def comparison_request?
    content.downcase.match?(/\b(compare|comparison|difference|different|versus|vs\.?|better)\b/)
  end

  def recommendation_refinement_request?
    extractor = FragrancePreferenceExtractor.new(content)
    confident_ai_intent?(%w[refine_recommendation closest_alternative]) || extractor.refinement?
  end

  def order_change_request?
    content.downcase.strip.match?(/\A(change|update|edit)\s+((my|the)\s+)?(previous\s+|last\s+)?order[?!. ]*\z/)
  end

  def correction_command?
    content.match?(/\A(?:actually[\s,]*)?(?:change|update)\s+(?:the\s+quantity|quantity|my\s+phone|phone|my\s+name|name|the\s+address|address)\b/i) ||
      content.match?(/\A(?:actually[\s,]*)?make\s+it\b/i) ||
      content.match?(/\A(?:my\s+name\s+is|amar\s+naam|amar\s+nam|name|naam)\s+.+(?:update|change).*(?:order)\b/i) ||
      variant_correction_request? || product_correction_request? ||
      content.match?(/\A(?:actually[\s,]*)?address(?:\s+ta)?\s+.+\s+(?:hobe|হবে)\z/i)
  end

  def variant_correction_request?
    return false if pending_order.product.blank? || pending_order.product.product_variants.empty?

    normalized = content.downcase.squish
    normalized.match?(/\b(actually|instead|change|size|previous|one before|ager|agerta|bigger|larger|next size|আগের)\b|আরও বড়/) &&
      (normalized.match?(/\b\d+(?:\.\d+)?\s*ml\b/) || normalized.match?(
        /\b(first|second|third|last|small|medium|large|bigger|larger|next size|best val(?:ue)?|ager|agerta|আগের)\b/
      ))
  end

  def product_correction_request?
    return false unless content.downcase.match?(/\b(actually|instead|change|not|na|wrong|বরং|না)\b/)

    catalog.available_for_sale.any? do |product|
      product.searchable_names.any? { |name| content.downcase.include?(name.downcase) }
    end
  end

  def ai_change_intent?
    confident_ai_intent?(%w[change_product change_quantity change_name change_phone change_address])
  end

  def intent_detector
    @intent_detector ||= ConversationIntentDetector.new(content)
  end

  def defer_confirmation_request?
    return false unless pending_order.awaiting_confirmation?
    return true if confident_ai_intent?(%w[defer_confirmation])

    normalized = content.downcase.squish
    normalized.match?(/\bconfirm\s+(later|letter)\b/) ||
      normalized.match?(/\b(will|i'll|i will)\s+confirm\b.*\b(later|letter)\b/) ||
      normalized.match?(/\b(pore|later)\s+confirm\s+(korbo|kore dibo)\b/) ||
      normalized.match?(/\bekhon\s+na\b|\bpore\s+korbo\b/)
  end

  def human_agent_request?
    confident_ai_intent?(%w[human_agent]) || content.downcase.match?(
      /\b(human|person|agent|seller|owner|manager|manush|মানুষ|সেলার)\b.*\b(talk|speak|connect|chai|kotha|কথা)\b|\b(talk|speak|connect|kotha|কথা)\b.*\b(human|person|agent|seller|owner|manager|manush|মানুষ|সেলার)\b/
    )
  end

  def remembered_value(field)
    return unless content.downcase.match?(/\b(same|previous|ager|আগের)\b/)

    previous_completed_order&.public_send(field)
  end

  def collect_remembered_checkout_value
    field, outcome, next_status = case pending_order.status
    when "collecting_name" then [ :customer_name, :name_collected, :collecting_phone ]
    when "collecting_phone" then [ :phone, :phone_collected, :collecting_address ]
    when "collecting_address" then [ :address, :address_collected, :awaiting_confirmation ]
    else return false
    end
    value = remembered_value(field)
    return false if value.blank?

    pending_order.public_send("#{field}=", value)
    advance_after_collection(next_status)
    @outcome = outcome
    true
  end

  def collect_explicit_checkout_value
    return false unless pending_order.collecting_name?
    return false unless content.match?(/\A(?:my\s+name\s+is|amar\s+naam|amar\s+nam|name|naam)\b/i)

    collect_name
    outcome == :name_collected
  end

  def select_exact_catalog_product
    return false unless pending_order.collecting_product?
    return false if pending_order.conversation.conversation_state.to_h["last_outcome"] == "product_variants_requested"

    normalized = normalize_catalog_name(content)
    product = catalog.available_for_sale.find do |candidate|
      candidate.searchable_names.any? { |name| normalize_catalog_name(name) == normalized }
    end
    return false if product.blank?

    collect_product
    true
  end

  def normalize_catalog_name(value)
    value.to_s.downcase.gsub(/[^a-z0-9]+/, " ").squish
  end

  def trustworthy_planned_checkout_details
    can_accept_explicit_entities = confident_ai_intent?(%w[select_product select_quantity provide_name provide_phone provide_address])
    return {} unless pending_order.status.in?(%w[collecting_name collecting_phone collecting_address]) || can_accept_explicit_entities

    details = {}
    name = interpretation&.entities&.[](:customer_name).presence || leading_customer_name
    details[:customer_name] = name unless name.blank? || non_name_reply?(name)
    phone = valid_phone_candidate(interpretation&.entities&.[](:phone), content)
    details[:phone] = phone if phone.present?
    address = interpretation&.entities&.[](:address).presence
    details[:address] = address if address.present?
    details
  end

  def leading_customer_name
    return unless pending_order.collecting_name? && content.include?(",")

    candidate = content.split(",", 2).first.to_s.strip
    candidate if candidate.match?(/\A[[:alpha:] .'-]{2,60}\z/u)
  end

  def extracted_customer_name
    match = content.match(/\A(?:my\s+name\s+is|amar\s+naam|amar\s+nam|name|naam)\s*[:=-]?\s*(.+?)[?!. ]*\z/i)
    match ? match[1].strip : content
  end

  def non_name_reply?(value)
    normalized = value.to_s.downcase.gsub(/[^a-z]/, "")
    return true if normalized.blank? || greeting?
    return true if Constants::Conversation::NON_NAME_REPLIES.include?(normalized)

    value.to_s.downcase.match?(/\A(that|it|this)\s+(works|is fine|is good)(\s+for\s+me)?[?!. ]*\z/)
  end

  def return_policy_question?
    normalized = content.downcase.squish
    policy_terms = normalized.match?(/\b(return|replacement|exchange|ferot|ফেরত)\b.*\b(policy|rules?|niyom|ase|ache|ki|what|how)\b/) ||
      normalized.match?(/\b(policy|rules?|niyom|ki)\b.*\b(return|replacement|exchange|ferot|ফেরত)\b/)
    explicit_request = normalized.match?(/\b(i want|want to|need to|please|korbo|korte chai|ferot dibo)\b.*\b(return|replace|exchange|ferot)\b/)
    policy_terms && !explicit_request
  end

  def previous_completed_order
    @previous_completed_order ||= pending_order.conversation.pending_orders
      .where.not(id: pending_order.id)
      .where(status: %i[confirmed submitted_to_woocommerce])
      .order(id: :desc).first
  end

  def confident_ai_intent?(intents)
    interpretation.present? && !interpretation.needs_clarification && interpretation.intent.in?(intents)
  end

  def interpreted_entity(key, for_intent:)
    return unless confident_ai_intent?([ for_intent ])

    interpretation.entities[key].presence
  end
end
