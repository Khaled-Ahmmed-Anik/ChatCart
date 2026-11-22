class CatalogueInquiryScope
  def initialize(business:, text:)
    @business = business
    @tokens = CatalogueCategoryResolver.normalize(text).split - Constants::Conversation::INQUIRY_STOP_WORDS
  end

  def products
    return [] if tokens.empty?

    ranked = business.products.available_for_sale.includes(:product_variants).filter_map do |product|
      next unless product.total_available_stock.positive?

      labels = [ *product.searchable_names, product.category ].compact
      words = labels.flat_map { |label| CatalogueCategoryResolver.normalize(label).split }.uniq
      overlap = (tokens & words).size
      [ product, overlap ] if overlap.positive?
    end
    best = ranked.map(&:last).max
    ranked.select { |_product, score| score == best }.map(&:first)
  end

  private

  attr_reader :business, :tokens
end
