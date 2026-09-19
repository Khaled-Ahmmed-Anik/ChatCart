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
    elsif apply_correction
      @outcome = :order_updated
    else
      @outcome = :confirmation_unclear
    end
  end

  def handle_conversational_intent
    @outcome = if restart_request?
      restart_order
      :restarted
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
      pending_order.update!(customer_name: Regexp.last_match(1).strip)
      true
    when /\A(?:change|update)\s+(?:the\s+)?address\s+(?:to\s+)?(.+)\z/i
      pending_order.update!(address: Regexp.last_match(1).strip)
      true
    else
      false
    end
  end

  def update_quantity(value)
    quantity = parse_quantity(value)
    return false if quantity.blank? || !pending_order.product.available_for_quantity?(quantity)

    pending_order.update!(quantity: quantity)
    true
  end

  def update_phone(value)
    phone = value.strip
    return false unless phone.match?(/\A[+\d][\d\s().-]{6,}\z/)

    pending_order.update!(phone: phone)
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
    content.downcase.strip.match?(/\A(restart|start over|new order|order again)[!. ]*\z/)
  end

  def price_question?
    content.downcase.match?(/\b(price|cost)\b|how much/)
  end

  def stock_question?
    content.downcase.match?(/\b(stock|available|availability)\b/)
  end
end
