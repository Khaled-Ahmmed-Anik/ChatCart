class CatalogueConversationReference
  def initialize(conversation:, text:)
    @conversation = conversation
    @original_text = text
    @text = ConversationTextNormalizer.call(text)
  end

  def product
    resolution = ProductResolutionService.new(business: conversation.business, query: text).resolve
    return resolution.product if resolution.matched?
    return if resolution.ambiguous?

    options = offered_products
    brand_matches = options.select do |product|
      brand = ConversationTextNormalizer.call(product.name).split.first
      brand.length > 2 && text.match?(/\b#{Regexp.escape(brand)}\b/)
    end
    return brand_matches.first if brand_matches.one?
    position = option_position
    return options[position] if position
    factual_follow_up = ConversationTurnRequest.new(@original_text).information_only? &&
      Constants::Catalogue::QUESTION_TOPICS.values.any? { |topic| text.match?(topic.fetch(:question)) }
    return options.first if options.one? && (text.match?(Constants::Catalogue::PRODUCT_REFERENCE) || factual_follow_up)

    state = conversation.conversation_state.to_h
    inquiry = state["product_inquiry"].to_h
    inquiry_product = ConversationProductInquiry.new(conversation.pending_order).product if
      inquiry["product_id"] && conversation.pending_order
    return inquiry_product if inquiry_product

    name = state["last_referenced_product"]
    conversation.business.products.available_for_sale.find_by(name: name) if name.present?
  end

  def option_position
    return if text.match?(/\b(?:every|per)\s+second\b/)

    Constants::Catalogue::OPTION_POSITIONS.find { |word, _| text.match?(/\b#{word}\b/) }&.last
  end

  def offered_products
    state = conversation.conversation_state.to_h
    offered = state["last_offered_options"].to_h
    ids = if offered["kind"] == "products"
      Array(offered["options"]).map { |option| option["id"] }
    else
      Array(state.dig("guided_sales", "context", "last_recommended_product_ids"))
    end
    products = conversation.business.products.available_for_sale.includes(:product_variants).where(id: ids).index_by(&:id)
    ids.filter_map { |id| products[id.to_i] }
  end

  private

  attr_reader :conversation, :text
end
