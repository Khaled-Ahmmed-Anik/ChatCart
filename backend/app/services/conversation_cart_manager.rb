class ConversationCartManager
  Result = Data.define(:outcome, :question)

  def initialize(message:, pending_order:)
    @message = message
    @order = pending_order
    @text = ConversationTextNormalizer.call(message.content.to_s.gsub("+", " and "))
  end

  def call
    return if ConversationTurnRequest.new(message.content).information_only?
    return clarification(translation("positive_quantity")) if message.content.to_s.tr("০১২৩৪৫৬৭৮৯", "0123456789").match?(/(?:\A|\s)-\s*\d/)
    if (correction = text.match(Constants::Conversation::CART_SHORT_CORRECTION))
      products = order.line_items.map(&:product).uniq.select do |product|
        ConversationTextNormalizer.call(product.name).split.include?(correction[1])
      end
      if products.one?
        return Result.new(outcome: :cart_locked, question: nil) if order.confirmed? || order.submitted_to_woocommerce?
        return update_item(product: products.first)
      end
    end
    matches = product_mentions
    unresolved_addition = unresolved_addition?(matches)
    repaired = resume_repair(matches)
    return repaired if repaired
    addition = text.match?(Constants::Conversation::CART_ADDITION) && !text.match?(/\b(?:not|don t|do not)\b/)
    awaiting_addition = order.conversation.conversation_state.to_h["cart_awaiting_product"] && matches.any?
    named_quantity = matches.one? && text.match?(Constants::Conversation::CART_NAMED_QUANTITY) && !addition
    item_update = matches.any? && text.match?(Constants::Conversation::CART_ITEM_UPDATE) && !addition
    command = replacement_request? || addition || awaiting_addition || named_quantity || item_update || text.match?(/\A(?:remove|delete|drop|change|update)|\b(?:aro|o|sathe)\s+.*(?:den|nibo)\b|\b(?:bad den|bad din)\z/)
    purchase = text.match?(/\b(?:order|take|want|buy|den|nibo|chai)\b/)
    multiple_clause = text.match?(/\b(?:and|ar|ebong)\b.+\b\d+\s*(?:pieces?|pcs?|ta|bottles?)\b/)
    quantity = ConversationQuantityParser.call(text, products: matches.map { |match| match[:product] })
    explicit_list = matches.any? && text.match?(Constants::Conversation::CART_CONJUNCTION) &&
      (matches.size > 1 || quantity.present? || unresolved_addition)
    return unless command || explicit_list || ((matches.size > 1 || multiple_clause) && purchase)
    return if text.match?(/\b(?:compare|difference|better|vs|nibo na|chai na|do not|don t)\b/)
    return if matches.any? do |match|
      text[match[:finish]..].to_s.match?(/\A\s+(?:na|not)\b/)
    end
    return if command && matches.empty? && !addition && !text.match?(/\A(?:remove|delete|drop)\b/)
    return if text.match?(/\A(?:change|update)\b/) && order.pending_order_items.none?
    return Result.new(outcome: :cart_locked, question: nil) if order.confirmed? || order.submitted_to_woocommerce?
    if matches.empty?
      order.conversation.update!(conversation_state: order.conversation.conversation_state.to_h.merge("cart_awaiting_product" => addition))
      key = text.match?(/\b(?:ager|aro|korte|korbo|cai|chai)\b/) ? "cart_banglish.choose_product" : "cart.choose_product"
      return clarification(I18n.t(key))
    end
    plans = build_plans(matches)
    if unresolved_addition
      store_repair(plans, replace_cart: replacement_request?, unknown: true)
      return clarification(translation("unknown"))
    end
    if text.match?(/\A(?:remove|delete|drop)\b|\b(?:bad den|bad din)\b/)
      return remove(text.match?(/\b(?:keep|thak)\b/) ? matches.first(1) : matches)
    end
    return update_item(matches.first) if item_update || named_quantity
    if order.product.present? && (order.quantity.blank? || !order.variant_selected_if_required?) &&
        matches.any? { |match| match[:product].id != order.product_id }
      return clarification("Let’s finish the option and quantity for #{order.product.name} first, then add the next item.")
    end

    if plans.any? { |plan| plan[:quantity].blank? || (plan[:product].available_variants.any? && plan[:variant].blank?) }
      if plans.size > 1
        store_repair(plans, replace_cart: replacement_request?)
        return repair_question(plans)
      end
      return start_addition(plans.first)
    end
    commit_plans(plans, replace_cart: replacement_request?)
  end

  private

  attr_reader :message, :order, :text

  def replacement_request?
    text.match?(Constants::Conversation::CART_REPLACEMENT)
  end

  def unresolved_addition?(matches)
    return false if matches.empty?

    masked = text.dup
    matches.reverse_each { |match| masked[match[:start]...match[:finish]] = " __known_product__ " }
    masked.split(Constants::Conversation::CART_CONJUNCTION).reject(&:blank?).any? do |clause|
      next false if clause.include?("__known_product__")
      next true if clause.match?(Constants::Conversation::EXPLICIT_PURCHASE_ACTION) ||
        clause.match?(Constants::Conversation::EXPLICIT_QUANTITY_UNITS)

      !ConversationTurnRequest.new(clause).information_only? &&
        ConversationActionPlanner::INFORMATIONAL_PATTERNS.values.none? { |pattern| clause.match?(pattern) }
    end
  end

  def build_plans(matches)
    matches.each_with_index.map do |match, index|
      segment = text[match[:start]...matches[index + 1]&.fetch(:start)]
      words = Constants::Conversation::NUMBER_WORDS.keys.map { |word| Regexp.escape(word) }.join("|")
      prefix = text[0...match[:start]][/(?:\A|\s)((?:\d+\s*(?:ta|pieces?|pcs?)?|#{words}))\s*\z/, 1]
      plan_for(match[:product], segment, prefix_quantity: ConversationQuantityParser.call(prefix))
    end
  end

  def store_repair(plans, replace_cart:, unknown: false)
    saved = plans.map { |plan| { "product_id" => plan[:product].id, "variant_id" => plan[:variant]&.id, "quantity" => plan[:quantity] } }
    conversation = order.conversation
    conversation.update!(conversation_state: conversation.conversation_state.to_h.merge("cart_repair" => {
      "pending_order_id" => order.id, "plans" => saved, "replace_cart" => replace_cart, "unknown" => unknown
    }))
  end

  def resume_repair(matches)
    repair = order.conversation.conversation_state.to_h["cart_repair"].to_h
    return unless repair["pending_order_id"] == order.id && matches.any?
    return if message.content.match?(/[?？]/) || ConversationActionPlanner::INFORMATIONAL_PATTERNS.values.any? { |pattern| text.match?(pattern) }
    return if text.match?(/\A(?:remove|delete|drop|change|update)\b/)
    return Result.new(outcome: :cart_locked, question: nil) if order.confirmed? || order.submitted_to_woocommerce?
    plans = Array(repair["plans"]).filter_map do |saved|
      product = order.conversation.business.products.available_for_sale.find_by(id: saved["product_id"])
      next unless product
      { product: product, variant: product.available_variants.find_by(id: saved["variant_id"]), quantity: saved["quantity"] }
    end
    return clarification(translation("unknown")) unless plans.size == Array(repair["plans"]).size
    updates = build_plans(matches)
    return unless updates.all? { |update| plans.any? { |plan| plan[:product] == update[:product] } }
    return unless updates.any? { |update| update[:variant] || update[:quantity] } || text.match?(Constants::Conversation::CART_DISCARD_UNKNOWN)
    updates.each do |update|
      candidates = plans.select { |plan| plan[:product] == update[:product] }
      return repair_question(plans) unless candidates.one?
      candidates.first[:variant] = update[:variant] if update[:variant]
      candidates.first[:quantity] = update[:quantity] if update[:quantity]
    end
    unknown = repair["unknown"] && !text.match?(Constants::Conversation::CART_DISCARD_UNKNOWN)
    plans.select! { |plan| matches.any? { |match| match[:product] == plan[:product] } } if repair["unknown"] && !unknown
    store_repair(plans, replace_cart: repair["replace_cart"], unknown: unknown)
    return clarification(translation("unknown")) if unknown
    return repair_question(plans) if plans.any? { |plan| plan[:quantity].blank? || (plan[:product].available_variants.any? && plan[:variant].blank?) }

    commit_plans(plans, replace_cart: repair["replace_cart"])
  end

  def repair_question(plans)
    missing = plans.select { |plan| plan[:quantity].blank? || (plan[:product].available_variants.any? && plan[:variant].blank?) }
    clarification(translation("repair", products: missing.map { |plan| plan[:product].name }.join(", ")))
  end

  def translation(key, **options)
    # Repair prompts follow the same deterministic language convention as existing cart prompts.
    banglish = text.match?(/\b(?:ar|ekta|duita|koren|korbo|nibo|shudhu|bad)\b/)
    I18n.t("#{banglish ? 'cart_banglish' : 'cart'}.#{key}", **options)
  end

  def commit_plans(plans, replace_cart:)
    return Result.new(outcome: :cart_inventory_unavailable, question: nil) unless available_additions?(plans, replace_cart: replace_cart)

    order.with_lock do
      replace_cart ? order.pending_order_items.destroy_all : order.save_current_item!
      plans[0...-1].each { |plan| add_saved_item(plan) }
      final = plans.last
      order.update!(product: final[:product], product_variant: final[:variant], quantity: final[:quantity], status: checkout_status)
    end
    clear_addition_context!
    Result.new(outcome: :cart_updated, question: nil)
  end

  def product_mentions
    products = order.conversation.business.products.available_for_sale.to_a
    matches = products.flat_map do |product|
      names = product.searchable_names.flat_map { |name| [ name, name.sub(/\Athe\s+/i, "") ] }.uniq
      names.filter_map do |name|
        label = ConversationTextNormalizer.call(name)
        text.to_enum(:scan, /(?:\A|\s)(#{Regexp.escape(label)})(?=\z|\s)/).map do
          match = Regexp.last_match
          { product: product, start: match.begin(1), finish: match.end(1) }
        end
      end
    end.flatten
    products.each do |product|
      codes = ConversationTextNormalizer.call(product.name).scan(/\b[a-z]+\d+[a-z0-9]*\b/)
      codes.each do |code|
        next if products.count { |other| ConversationTextNormalizer.call(other.name).split.include?(code) } != 1
        brand = Regexp.escape(ConversationTextNormalizer.call(product.name).split.first)
        if (match = text.match(/\b(?:#{brand}\s+)?#{Regexp.escape(code)}\b/))
          matches << { product: product, start: match.begin(0), finish: match.end(0) }
        end
      end
    end
    if matches.empty? && (text.match?(/\A(?:remove|delete|drop|make|change|update)|\b(?:bad den|koren|kore den)\b/) ||
        text.match?(Constants::Conversation::CART_ADDITION))
      order.line_items.map(&:product).uniq.group_by(&:category).each do |category, items|
        next if category.blank? || items.size != 1
        if (match = text.match(/\b#{Regexp.escape(category.downcase)}\b/))
          matches << { product: items.first, start: match.begin(0), finish: match.end(0) }
        end
      end
    end
    matches.sort_by! { |match| [ match[:start], -(match[:finish] - match[:start]) ] }
    matches.reject! do |match|
      same_span = matches.select { |other| other[:start] == match[:start] && other[:finish] == match[:finish] }
      same_span.map { |other| other[:product].id }.uniq.size > 1
    end
    matches.each_with_object([]) do |match, selected|
      selected << match unless selected.any? { |other| match[:start] < other[:finish] && match[:finish] > other[:start] }
    end
  end

  def plan_for(product, segment, prefix_quantity: nil)
    plan = ConversationActionPlanner.new(message: Struct.new(:content).new(segment), business: order.conversation.business, current_product: product).call
    quantity = prefix_quantity || plan.quantity
    remainder = product.searchable_names.reduce(segment) { |value, name| value.gsub(ConversationTextNormalizer.call(name), "") }
    quantity ||= remainder.strip.to_i if remainder.strip.match?(/\A\d+\z/)
    quantity ||= remainder[/\bto\s+(\d+)\z/, 1]&.to_i
    { product: product, variant: plan.variant, quantity: quantity }
  end

  def available_additions?(plans, replace_cart: false)
    totals = replace_cart ? {} : order.line_items.to_h { |item| [ [ item.product_id, item.product_variant_id ], item.quantity ] }
    plans.all? do |plan|
      key = [ plan[:product].id, plan[:variant]&.id ]
      totals[key] = totals.fetch(key, 0) + plan[:quantity]
      (plan[:variant] || plan[:product]).available_for_quantity?(totals[key])
    end
  end

  def add_saved_item(plan)
    item = order.pending_order_items.find_or_initialize_by(product: plan[:product], product_variant: plan[:variant])
    item.update!(quantity: item.quantity.to_i + plan[:quantity])
  end

  def start_addition(plan)
    if order.product.present? && (order.quantity.blank? || !order.variant_selected_if_required?)
      return clarification("Let’s finish the option and quantity for #{order.product.name} first, then add #{plan[:product].name}.")
    end
    order.with_lock do
      order.save_current_item!
      status = plan[:product].available_variants.any? && plan[:variant].blank? ? :collecting_variant : :collecting_quantity
      order.update!(product: plan[:product], product_variant: plan[:variant], quantity: plan[:quantity], status: status)
    end
    clear_addition_context!
    Result.new(outcome: :cart_updated, question: nil)
  end

  def remove(matches)
    product_ids = matches.map { |match| match[:product].id }
    return clarification("That product isn’t in this order. Which item would you like to remove?") unless order.line_items.any? { |item| item.product_id.in?(product_ids) } || order.product_id.in?(product_ids)
    order.with_lock do
      order.pending_order_items.where(product_id: product_ids).destroy_all
      if order.product_id.in?(product_ids)
        replacement = order.pending_order_items.first
        order.update!(product: replacement&.product, product_variant: replacement&.product_variant,
          quantity: replacement&.quantity, status: replacement ? checkout_status : :collecting_product)
        replacement&.destroy!
      end
    end
    Result.new(outcome: :cart_updated, question: nil)
  end

  def update_item(match)
    plan = plan_for(match[:product], text)
    return clarification("How many #{match[:product].name} would you like? Include the option if you have more than one.") if plan[:quantity].blank?
    candidates = order.line_items.select { |item| item.product_id == match[:product].id }
    candidates.select! { |item| item.product_variant_id == plan[:variant].id } if plan[:variant]
    return clarification("Which option of #{match[:product].name} should I change?") unless candidates.one?
    item = candidates.first
    return Result.new(outcome: :cart_inventory_unavailable, question: nil) unless (item.product_variant || item.product).available_for_quantity?(plan[:quantity])

    order.with_lock do
      if order.product_id == item.product_id && order.product_variant_id == item.product_variant_id
        order.pending_order_items.where(product_id: item.product_id, product_variant_id: item.product_variant_id).destroy_all
        order.update!(quantity: plan[:quantity], status: checkout_status)
      else
        item.update!(quantity: plan[:quantity])
        order.update!(status: checkout_status)
      end
    end
    Result.new(outcome: :cart_updated, question: nil)
  end

  def checkout_status
    return :collecting_name if order.customer_name.blank?
    return :collecting_phone if order.phone.blank?
    return :collecting_address if order.address.blank?

    :awaiting_confirmation
  end

  def clarification(question) = Result.new(outcome: :cart_needs_details, question: question)

  def clear_addition_context!
    conversation = order.conversation
    conversation.update!(conversation_state: conversation.conversation_state.to_h.except("cart_awaiting_product", "cart_repair"))
  end
end
