class CataloguePriceQuote
  def initialize(conversation:, text:)
    @conversation = conversation
    @text = text
  end

  def content(language: "english")
    quantity = ConversationQuantityParser.call(text, products: conversation.business.products.available_for_sale.to_a)
    return if quantity.blank?

    reference = CatalogueConversationReference.new(conversation: conversation, text: text)
    categories = CatalogueCategoryResolver.call(business: conversation.business, text: text)
    matches = conversation.business.products.available_for_sale.where(category: categories).includes(:product_variants).to_a
    product = matches.one? ? matches.first : reference.product
    product ||= reference.offered_products.first if reference.offered_products.one?
    return if product.blank?

    locale = language == "banglish" ? "banglish" : "en"
    I18n.t("catalogue_quotes.#{locale}.subtotal", count: quantity, product: product.name,
      unit: money(product.starting_price), total: money(product.starting_price * quantity))
  end

  private

  attr_reader :conversation, :text

  def money(value)
    "৳#{value.frac.zero? ? value.to_i : value}"
  end
end
