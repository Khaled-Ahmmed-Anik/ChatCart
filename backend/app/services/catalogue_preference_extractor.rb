class CataloguePreferenceExtractor
  def initialize(message, business:)
    @message = ConversationTextNormalizer.call(message)
    @business = business
  end

  def fragrance?
    return true if business.category.to_s.match?(/perfume|fragrance|attar/i)
    return false if business.category.present? && business.category != "retail"

    products.any? do |product|
      product.product_attributes.to_h.key?("scent_families") || product.name.match?(/perfume|fragrance|oud|musk/i)
    end
  end

  def call(existing: {})
    common = FragrancePreferenceExtractor.new(message).call(existing: existing)
    return common if fragrance?

    common.except!("scent_families", "avoid_scent_families", "performance", "projection_preference", "maximum_projection", "format")
    attributes = common["attributes"].to_h.dup
    excluded = common["excluded_attributes"].to_h.dup
    available_attributes.each do |key, values|
      matches = values.select { |value| mentions?(value) }
      next if matches.empty?

      rejected, accepted = matches.partition { |value| rejected?(value) }
      excluded[key] = (Array(excluded[key]) + rejected).uniq if rejected.any?
      attributes[key] = accepted if accepted.any?
      attributes[key] = Array(attributes[key]) - rejected if rejected.any?
    end
    common.merge("attributes" => attributes, "excluded_attributes" => excluded)
  end

  def meaningful? = fragrance? ? FragrancePreferenceExtractor.new(message).meaningful? : call.values.any?(&:present?)
  def refinement?
    FragrancePreferenceExtractor.new(message).refinement? ||
      (message.match?(/\b(?:instead|rather|not|no|avoid|without|na|change)\b/) && available_attributes.values.flatten.any? { |value| mentions?(value) })
  end

  def available_attributes
    @available_attributes ||= products.each_with_object({}) do |product, attributes|
      product.product_attributes.to_h.each do |key, values|
        next unless values.is_a?(String) || values.is_a?(Array)

        attributes[key] = (Array(attributes[key]) + Array(values).select { |value| value.is_a?(String) }).uniq
      end
    end
  end

  private

  attr_reader :message, :business
  def products = @products ||= business.products.available_for_sale.includes(:product_variants).to_a
  def mentions?(value) = message.match?(/(?:\A|\s)#{Regexp.escape(ConversationTextNormalizer.call(value))}(?:\z|\s)/)
  def rejected?(value)
    label = Regexp.escape(ConversationTextNormalizer.call(value))
    message.match?(/\b(?:not|no|avoid|without)\s+#{label}\b|\b#{label}\s+(?:na|chai na)\b/)
  end
end
