class ConversationCartManager
  Result = Data.define(:outcome, :question)

  def initialize(message:, pending_order:)
    @message = message
    @order = pending_order
    @text = ConversationTextNormalizer.call(message.content)
  end

  def call
    matches = product_mentions
    command = text.match?(/\A(?:add|also add|include|remove|delete|drop|change|update)|\b(?:aro|o|sathe)\s+.*(?:den|nibo)\b|\b(?:bad den|bad din)\z/)
    purchase = text.match?(/\b(?:order|take|want|buy|den|nibo|chai)\b/)
    multiple_clause = text.match?(/\b(?:and|ar|ebong)\b.+\b\d+\s*(?:pieces?|pcs?|ta|bottles?)\b/)
    return unless command || ((matches.size > 1 || multiple_clause) && purchase)
    return if text.match?(/\b(?:compare|difference|better|vs|nibo na|chai na|do not|don t)\b/)
    return if matches.any? do |match|
      text[match[:finish]..].to_s.match?(/\A\s+(?:na|not)\b/)
    end
    return if command && matches.empty? && !text.match?(/\A(?:add|include|remove|delete|drop)\b/)
    return if text.match?(/\A(?:change|update)\b/) && order.pending_order_items.none?
    return Result.new(outcome: :cart_locked, question: nil) if order.confirmed? || order.submitted_to_woocommerce?
    return clarification("Which product would you like to add or change? Please send its name.") if matches.empty?
    final_tail = text[matches.last[:finish]..].to_s
    if final_tail.match?(/\b(?:and|ar|ebong)\b\s+\S/) &&
        ConversationActionPlanner::INFORMATIONAL_PATTERNS.values.none? { |pattern| final_tail.match?(pattern) }
      return clarification("Please send the exact product name for each item you want to add.")
    end
    return remove(matches) if text.match?(/\A(?:remove|delete|drop)\b|\b(?:bad den|bad din)\z/)
    return update_item(matches.first) if text.match?(/\A(?:change|update)\b/) && matches.one?
    if order.product.present? && (order.quantity.blank? || !order.variant_selected_if_required?) &&
        matches.any? { |match| match[:product].id != order.product_id }
      return clarification("Let’s finish the option and quantity for #{order.product.name} first, then add the next item.")
    end

    plans = matches.each_with_index.map do |match, index|
      segment = text[match[:start]...matches[index + 1]&.fetch(:start)]
      plan_for(match[:product], segment)
    end
    if plans.any? { |plan| plan[:quantity].blank? || (plan[:product].available_variants.any? && plan[:variant].blank?) }
      return clarification("Please include the quantity and available option for each product you want to order.") if plans.size > 1
      return start_addition(plans.first)
    end
    return Result.new(outcome: :cart_inventory_unavailable, question: nil) unless available_additions?(plans)

    order.with_lock do
      order.save_current_item!
      plans[0...-1].each { |plan| add_saved_item(plan) }
      final = plans.last
      order.update!(product: final[:product], product_variant: final[:variant], quantity: final[:quantity], status: checkout_status)
    end
    Result.new(outcome: :cart_updated, question: nil)
  end

  private

  attr_reader :message, :order, :text

  def product_mentions
    matches = order.conversation.business.products.available_for_sale.flat_map do |product|
      product.searchable_names.filter_map do |name|
        label = ConversationTextNormalizer.call(name)
        text.to_enum(:scan, /(?:\A|\s)(#{Regexp.escape(label)})(?=\z|\s)/).map do
          match = Regexp.last_match
          { product: product, start: match.begin(1), finish: match.end(1) }
        end
      end
    end.flatten.sort_by { |match| [ match[:start], -(match[:finish] - match[:start]) ] }
    matches.each_with_object([]) do |match, selected|
      selected << match unless selected.any? { |other| match[:start] < other[:finish] && match[:finish] > other[:start] }
    end
  end

  def plan_for(product, segment)
    plan = ConversationActionPlanner.new(message: Struct.new(:content).new(segment), business: order.conversation.business, current_product: product).call
    quantity = plan.quantity
    remainder = product.searchable_names.reduce(segment) { |value, name| value.gsub(ConversationTextNormalizer.call(name), "") }
    quantity ||= remainder.strip.to_i if remainder.strip.match?(/\A\d+\z/)
    quantity ||= remainder[/\bto\s+(\d+)\z/, 1]&.to_i
    { product: product, variant: plan.variant, quantity: quantity }
  end

  def available_additions?(plans)
    totals = order.line_items.to_h { |item| [ [ item.product_id, item.product_variant_id ], item.quantity ] }
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
end
