class ConversationMessageProcessor
  NUMBER_WORDS = {
    "one" => 1, "two" => 2, "three" => 3, "four" => 4, "five" => 5,
    "six" => 6, "seven" => 7, "eight" => 8, "nine" => 9, "ten" => 10
  }.freeze

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

    return pending_order if handle_order_update_request
    return pending_order if handle_conversational_intent
    return pending_order if handle_ai_intent

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

  AI_OUTCOMES = {
    "greeting" => :greeting,
    "thanks" => :thanks,
    "help" => :help,
    "wellbeing" => :wellbeing,
    "goodbye" => :goodbye,
    "bot_identity" => :bot_identity,
    "language_preference" => :language_preference,
    "complaint" => :complaint,
    "human_agent" => :human_agent,
    "list_products" => :product_list_requested,
    "product_search" => :product_list_requested,
    "product_details" => :product_details_requested,
    "product_price" => :price_inquiry,
    "product_availability" => :stock_inquiry,
    "product_recommendation" => :product_recommendation_requested,
    "compare_products" => :product_comparison_requested,
    "product_variants" => :product_variants_requested,
    "product_images" => :product_images_requested,
    "out_of_stock" => :alternative_product_requested,
    "alternative_product" => :alternative_product_requested,
    "resume_order" => :resume_order_requested,
    "order_history" => :order_history_requested,
    "payment_methods" => :payment_methods_requested,
    "cash_on_delivery" => :cash_on_delivery_requested,
    "delivery_charge" => :delivery_charge_requested,
    "delivery_area" => :delivery_area_requested,
    "delivery_time" => :delivery_time_requested,
    "return_request" => :return_requested,
    "replacement_request" => :replacement_requested,
    "refund_request" => :refund_requested
  }.freeze

  def handle_ai_intent
    return false if interpretation.blank?

    if interpretation.needs_clarification || interpretation.intent == "unclear"
      @outcome = :clarification_needed
      return true
    end

    @outcome = AI_OUTCOMES[interpretation.intent]
    outcome.present?
  end

  def mapped_secondary_outcomes
    return [] if interpretation.blank? || interpretation.needs_clarification

    interpretation.secondary_intents.filter_map do |intent|
      next unless intent.in?(ConversationIntentRegistry::INFORMATIONAL_INTENTS)

      AI_OUTCOMES[intent]
    end.uniq - [ outcome ]
  end

  def collect_product
    product = matching_product
    if product.blank?
      @outcome = named_unavailable_product? ? :product_unavailable : :product_not_found
      return
    end

    pending_order.product = product
    pending_order.product_variant = matching_variant(product)
    pending_order.status = pending_order.product_variants_required? && pending_order.product_variant.blank? ?
      :collecting_variant : :collecting_quantity
    pending_order.save!
    @outcome = :product_selected
  end

  def collect_variant
    variant = matching_variant(pending_order.product)
    if variant.blank?
      @outcome = :variant_not_found
      return
    end

    pending_order.update!(product_variant: variant, status: :collecting_quantity)
    @outcome = :variant_selected
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
    name = interpreted_entity(:customer_name, for_intent: "provide_name") || remembered_value(:customer_name) || content
    return if name.blank?

    pending_order.customer_name = name
    advance_after_collection(:collecting_phone)
    @outcome = :name_collected
  end

  def collect_phone
    phone = interpreted_entity(:phone, for_intent: "provide_phone") || remembered_value(:phone) || content
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
    elsif order_details_request?
      :order_details_requested
    elsif greeting?
      :greeting
    elsif help_request?
      :help
    elsif thanks?
      :thanks
    elsif budget_recommendation_request?
      :product_recommendation_requested
    elsif price_question?
      :price_inquiry
    elsif stock_question?
      :stock_inquiry
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
    return apply_ai_correction if ai_change_intent?

    case content
    when /\A(?:change|update)\s+(?:the\s+)?quantity\s+(?:to\s+)?(.+)\z/i
      update_quantity(Regexp.last_match(1))
    when /\A(?:change|update)\s+(?:my\s+)?phone\s+(?:to\s+)?(.+)\z/i
      update_phone(Regexp.last_match(1))
    when /\A(?:change|update)\s+(?:my\s+)?name\s+(?:to\s+)?(.+)\z/i
      record_change(:customer_name, Regexp.last_match(1).strip)
    when /\A(?:change|update)\s+(?:the\s+)?address\s+(?:to\s+)?(.+)\z/i
      record_change(:address, Regexp.last_match(1).strip)
    else
      false
    end
  end

  def apply_ai_correction
    case interpretation.intent
    when "change_quantity"
      update_quantity(interpretation.entities[:quantity].to_s)
    when "change_phone"
      update_phone(interpretation.entities[:phone].to_s)
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
    product = catalog.active.in_stock.find_by("LOWER(name) = ?", name.downcase)
    return false if product.blank?

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

  def update_quantity(value)
    quantity = parse_quantity(value)
    return false if quantity.blank? || selected_inventory.blank? || !selected_inventory.available_for_quantity?(quantity)

    record_change(:quantity, quantity)
  end

  def update_phone(value)
    phone = value.strip
    return false unless phone.match?(/\A[+\d][\d\s().-]{6,}\z/)

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
    phone = interpretation.entities[:phone].to_s.strip
    return false unless phone_number?(phone)

    pending_order.update!(phone: phone, status: :collecting_address)
    true
  end

  def advance_after_collection(next_status)
    pending_order.status = pending_order.ready_for_confirmation? ? :awaiting_confirmation : next_status
    pending_order.save!
  end

  def matching_product
    interpreted_name = interpreted_entity(:product_name, for_intent: "select_product")
    if interpreted_name.present?
      interpreted_product = catalog.active.includes(:product_variants).find_by("LOWER(name) = ?", interpreted_name.downcase)
      return interpreted_product if interpreted_product&.total_available_stock.to_i.positive?
    end

    catalog.active.includes(:product_variants).find do |product|
      product.total_available_stock.positive? && content.downcase.include?(product.name.downcase)
    end
  end

  def matching_variant(product)
    return if product.blank? || product.product_variants.none?

    requested = interpretation&.entities&.values_at(:variant_name, :size)&.find(&:present?)
    product.available_variants.find do |variant|
      candidates = [ variant.name, variant.size ].compact.map(&:downcase)
      candidates.include?(requested.to_s.downcase) || candidates.any? { |candidate| content.downcase.include?(candidate) }
    end
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
    numeric_quantity = value[/\d+/]&.to_i
    return numeric_quantity if numeric_quantity&.positive?

    NUMBER_WORDS.find { |word, _number| value.downcase.match?(/\b#{word}\b/) }&.last
  end

  def phone_number?(value = content)
    value.match?(/\A[+\d][\d\s().-]{6,}\z/)
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
    content.downcase.strip.match?(/\A(hi|hello|hey|assalamu alaikum|assalamualaikum)[!. ]*\z/)
  end

  def help_request?
    content.downcase.match?(/\b(help|options|menu)\b/)
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

  def budget_recommendation_request?
    normalized = content.downcase.tr("০১২৩৪৫৬৭৮৯", "0123456789")
    normalized.match?(/\b(under|below|within|budget|cheapest|lowest|starting price|price starts|kom dam|moddhe)\b|মধ্যে|নিচে|বাজেট|কম দাম/)
  end

  def stock_question?
    content.downcase.match?(/\b(stock|available|availability)\b/)
  end

  def order_change_request?
    content.downcase.strip.match?(/\A(change|update|edit)\s+((my|the)\s+)?(previous\s+|last\s+)?order[?!. ]*\z/)
  end

  def correction_command?
    content.match?(/\A(?:change|update)\s+(?:the\s+quantity|quantity|my\s+phone|phone|my\s+name|name|the\s+address|address)\b/i)
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
