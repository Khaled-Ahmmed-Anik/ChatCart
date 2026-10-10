class ConversationProductInquiry
  def initialize(pending_order)
    @order = pending_order
  end

  def product
    reference = state["product_inquiry"].to_h
    return unless reference["pending_order_id"] == order.id

    candidate = order.conversation.business.products.available_for_sale.find_by(id: reference["product_id"])
    candidate if candidate&.total_available_stock.to_i.positive?
  end

  def remember!(content)
    resolution = ProductResolutionService.new(business: order.conversation.business, query: content).resolve
    return clear! if resolution.ambiguous?
    selected = resolution.product if resolution.matched?
    unless selected
      normalized = ConversationTextNormalizer.call(content)
      named = order.conversation.business.products.available_for_sale.select do |candidate|
        candidate.searchable_names.flat_map { |name| [ name, name.sub(/\Athe\s+/i, "") ] }.any? do |name|
          label = Regexp.escape(ConversationTextNormalizer.call(name))
          normalized.match?(/(?:\A|\s)#{label}(?:\z|\s)/)
        end
      end
      return clear! if named.many?
      selected = named.first
    end
    unless selected
      return if content.match?(Constants::Conversation::INQUIRY_VARIANT_FOLLOW_UP) || content.match?(Constants::Conversation::INQUIRY_REFERENCE)
      return clear!
    end

    variant = selected.available_variants.find do |option|
      [ option.name, option.size ].compact.any? do |label|
        pattern = Regexp.escape(ConversationTextNormalizer.call(label)).gsub("\\ ", "\\s*")
        ConversationTextNormalizer.call(content).match?(/(?:\A|\s)#{pattern}(?:\z|\s)/)
      end
    end
    order.conversation.update!(conversation_state: state.merge("product_inquiry" => {
      "product_id" => selected.id, "pending_order_id" => order.id, "variant_id" => variant&.id
    }.compact))
  end

  def variant
    product&.available_variants&.find_by(id: state.dig("product_inquiry", "variant_id"))
  end

  def clear!
    order.conversation.update!(conversation_state: state.except("product_inquiry", "last_referenced_product"))
  end

  private

  attr_reader :order

  def state = order.conversation.conversation_state.to_h
end
