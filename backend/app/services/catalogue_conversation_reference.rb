class CatalogueConversationReference
  def initialize(conversation:, text:)
    @conversation = conversation
    @text = ConversationTextNormalizer.call(text)
  end

  def product
    resolution = ProductResolutionService.new(business: conversation.business, query: text).resolve
    return resolution.product if resolution.matched?
    return if resolution.ambiguous?

    options = offered_products
    position = Constants::Catalogue::OPTION_POSITIONS.find { |word, _| text.match?(/\b#{word}\b/) }&.last
    return options[position] if position
    return options.first if options.one? && text.match?(Constants::Catalogue::PRODUCT_REFERENCE)

    name = conversation.conversation_state.to_h["last_referenced_product"]
    conversation.business.products.available_for_sale.find_by(name: name) if name.present?
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
