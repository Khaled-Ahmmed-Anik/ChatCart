class ProductImportApprover
  def initialize(draft:, attributes: {})
    @draft = draft
    @attributes = attributes.to_h.symbolize_keys
  end

  def approve!
    raise ArgumentError, "Import is not awaiting review" unless draft.status == "pending_review"

    data = draft.extracted_data.symbolize_keys.merge(attributes)
    if data[:duplicate_product_id].present?
      raise ArgumentError, "This source is already linked to product ##{data[:duplicate_product_id]}"
    end
    variants = Array(data.delete(:variants))
    product = draft.business.products.create!(
      data.slice(:name, :short_description, :description, :category, :tags, :product_type,
        :source_url, :woo_commerce_product_id, :image_urls).merge(
          price: data[:price].presence || variants.first&.dig("price") || 0,
          stock_quantity: data[:stock_quantity].presence || 0,
          active: false,
          import_status: "reviewed",
          imported_at: Time.current,
          product_variants_attributes: variants
        )
    )
    draft.update!(status: "approved", product: product)
    product
  end

  private

  attr_reader :draft, :attributes
end
