class CatalogueKnowledgeProfile
  def initialize(product)
    @product = product
  end

  def facts
    raw = product.product_attributes.to_h["catalogue_facts"]
    return {} unless raw.is_a?(Hash)

    raw.select do |topic, value|
      Constants::Catalogue::QUESTION_TOPICS.key?(topic.to_sym) && value.is_a?(String) &&
        value.strip.present? && value.length <= Constants::Catalogue::MAXIMUM_FACT_LENGTH
    end.transform_values(&:strip)
  end

  def status
    {
      profile: profile_name,
      source: "seller_catalogue",
      independently_verified: false,
      missing_fields: missing_fields,
      missing_topics: expected_topics - facts.keys,
      available_topics: facts.keys.sort
    }
  end

  private

  attr_reader :product

  def profile_name
    @profile_name ||= [ product.category, product.business.category ].filter_map do |category|
      next if category.blank?

      Constants::Catalogue::KNOWLEDGE_PROFILES.find { |_name, definition| category.match?(definition.fetch(:category)) }&.first
    end.first || "general"
  end

  def expected_topics
    Constants::Catalogue::KNOWLEDGE_PROFILES.dig(profile_name, :topics) || []
  end

  def missing_fields
    fields = []
    fields << "description" if product.description.blank?
    fields << "image_urls" if product.image_urls.blank?
    fields << "category" if product.category.blank?
    fields
  end
end
