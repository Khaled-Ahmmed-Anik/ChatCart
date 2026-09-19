class ConversationMessageProcessor
  NUMBER_WORDS = {
    "one" => 1, "two" => 2, "three" => 3, "four" => 4, "five" => 5,
    "six" => 6, "seven" => 7, "eight" => 8, "nine" => 9, "ten" => 10
  }.freeze

  attr_reader :outcome

  def initialize(message:, pending_order:)
    @message = message
    @pending_order = pending_order
    @content = message.content.to_s.strip
  end

  def process
    unless message.customer?
      @outcome = :ignored
      return pending_order
    end

    return pending_order if handle_order_update_request
    return pending_order if handle_conversational_intent

    case pending_order.status
    when "collecting_product"
      collect_product
    when "collecting_quantity"
      collect_quantity
    when "collecting_name"
      collect_name
    when "collecting_phone"
      collect_phone
    when "collecting_address"
      collect_address
    when "awaiting_confirmation"
      collect_confirmation
    end

    @outcome ||= :no_change
    pending_order
  end

  private

  attr_reader :message, :pending_order, :content

  def collect_product
    product = matching_product
    if product.blank?
      @outcome = named_unavailable_product? ? :product_unavailable : :product_not_found
      return
    end

    pending_order.product = product
    pending_order.status = :collecting_quantity
    pending_order.save!
    @outcome = :product_selected
  end

  def collect_quantity
    quantity = parsed_quantity
    if quantity.blank?
      @outcome = :invalid_quantity
      return
    end
    if pending_order.product.present? && !pending_order.product.available_for_quantity?(quantity)
      @outcome = :quantity_unavailable
      return
    end

    pending_order.quantity = quantity
    advance_after_collection(:collecting_name)
    @outcome = :quantity_collected
  end

  def collect_name
    return if content.blank?

    pending_order.customer_name = content
    advance_after_collection(:collecting_phone)
    @outcome = :name_collected
  end

  def collect_phone
    unless phone_number?
      @outcome = :invalid_phone
      return
    end

    pending_order.phone = content
    advance_after_collection(:collecting_address)
    @outcome = :phone_collected
  end

  def collect_address
    return if content.blank?

    pending_order.address = content
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
    return false unless order_change_request? || correction_command?
    return false unless pending_order.status.in?(%w[awaiting_confirmation confirmed submitted_to_woocommerce cancelled])

    @outcome = if pending_order.submitted_to_woocommerce?
      :submitted_order_change_requested
    elsif pending_order.cancelled?
      :cancelled_order_change_requested
    elsif order_change_request?
      :order_change_requested
    elsif apply_correction
      reopen_confirmed_order
    else
      :invalid_order_update
    end

    true
  end

  def reopen_confirmed_order
    return :order_updated unless pending_order.confirmed?

    pending_order.update!(status: :awaiting_confirmation)
    :confirmed_order_updated
  end

  def handle_conversational_intent
    @outcome = if restart_request?
      restart_order
      :restarted
    elsif order_details_request?
      :order_details_requested
    elsif greeting?
      :greeting
    elsif help_request?
      :help
    elsif thanks?
      :thanks
    elsif price_question?
      :price_inquiry
    elsif stock_question?
      :stock_inquiry
    end

    outcome.present?
  end

  def restart_order
    pending_order.update!(
      product: nil,
      quantity: nil,
      customer_name: nil,
      phone: nil,
      address: nil,
      status: :collecting_product
    )
  end

  def apply_correction
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

  def update_quantity(value)
    quantity = parse_quantity(value)
    return false if quantity.blank? || !pending_order.product.available_for_quantity?(quantity)

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

  def advance_after_collection(next_status)
    pending_order.status = pending_order.ready_for_confirmation? ? :awaiting_confirmation : next_status
    pending_order.save!
  end

  def matching_product
    Product.active.in_stock.find do |product|
      content.downcase.include?(product.name.downcase)
    end
  end

  def named_unavailable_product?
    Product.find_each.any? { |product| content.downcase.include?(product.name.downcase) }
  end

  def parsed_quantity
    parse_quantity(content)
  end

  def parse_quantity(value)
    numeric_quantity = value[/\d+/]&.to_i
    return numeric_quantity if numeric_quantity&.positive?

    NUMBER_WORDS.find { |word, _number| value.downcase.match?(/\b#{word}\b/) }&.last
  end

  def phone_number?
    content.match?(/\A[+\d][\d\s().-]{6,}\z/)
  end

  def confirmation?
    normalized_content.in?(%w[confirm confirmed yes y])
  end

  def cancellation?
    normalized_content.in?(%w[cancel cancelled stop no n])
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
    intent_detector.new_order?
  end

  def order_details_request?
    intent_detector.order_details?
  end

  def price_question?
    content.downcase.match?(/\b(price|cost)\b|how much/)
  end

  def stock_question?
    content.downcase.match?(/\b(stock|available|availability)\b/)
  end

  def order_change_request?
    content.downcase.strip.match?(/\A(change|update|edit)\s+(my\s+)?(previous\s+|last\s+)?order[!. ]*\z/)
  end

  def correction_command?
    content.match?(/\A(?:change|update)\s+(?:the\s+quantity|quantity|my\s+phone|phone|my\s+name|name|the\s+address|address)\b/i)
  end

  def intent_detector
    @intent_detector ||= ConversationIntentDetector.new(content)
  end
end
