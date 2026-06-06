class ConversationMessageProcessor
  def initialize(message:, pending_order:)
    @message = message
    @pending_order = pending_order
    @content = message.content.to_s.strip
  end

  def process
    return pending_order unless message.customer?

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

    pending_order
  end

  private

  attr_reader :message, :pending_order, :content

  def collect_product
    product = matching_product
    return if product.blank?

    pending_order.product = product
    pending_order.status = :collecting_quantity
    pending_order.save!
  end

  def collect_quantity
    quantity = content[/\d+/].to_i
    return unless quantity.positive?
    return if pending_order.product.present? && !pending_order.product.available_for_quantity?(quantity)

    pending_order.quantity = quantity
    advance_after_collection(:collecting_name)
  end

  def collect_name
    return if content.blank?

    pending_order.customer_name = content
    advance_after_collection(:collecting_phone)
  end

  def collect_phone
    return unless phone_number?

    pending_order.phone = content
    advance_after_collection(:collecting_address)
  end

  def collect_address
    return if content.blank?

    pending_order.address = content
    advance_after_collection(:awaiting_confirmation)
  end

  def collect_confirmation
    if confirmation?
      pending_order.confirmed!
    elsif cancellation?
      pending_order.cancelled!
    end
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
end
