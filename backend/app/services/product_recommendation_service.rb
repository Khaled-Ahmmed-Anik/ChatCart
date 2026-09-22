class ProductRecommendationService
  Offer = Data.define(:product, :variant, :price, :stock_quantity) do
    def label
      variant ? "#{product.name} #{variant.display_name}" : product.name
    end
  end
  Result = Data.define(
    :offers, :minimum_price, :requested_minimum, :requested_maximum, :budget_detected, :floor_request,
    :clarification_question, :exact_match
  )

  def initialize(business:, message:, preferences: {}, limit: 3)
    @business = business
    @message = message.to_s
    @preferences = preferences.to_h.stringify_keys
    @limit = limit
  end

  def call
    minimum, maximum, detected = price_bounds
    eligible = offers.select do |offer|
      (minimum.blank? || offer.price >= minimum) && (maximum.blank? || offer.price <= maximum) &&
        matches_price_direction?(offer)
    end
    exact_match = eligible.any?
    candidates = exact_match ? eligible : closest_candidates(minimum: minimum, maximum: maximum)
    product_offers = candidates.group_by { |offer| offer.product.id }.values.map do |product_options|
      preferred_offer(product_options, minimum: minimum, maximum: maximum, exact_match: exact_match)
    end
    ranked = product_offers.sort_by do |offer|
      if !exact_match && (minimum.present? || maximum.present?)
        [ constraint_distance(offer, minimum:, maximum:), -preference_score(offer), offer.label ]
      elsif floor_request?
        [ offer.price, -preference_score(offer), offer.label ]
      else
        [ -preference_score(offer), offer.price, offer.label ]
      end
    end.first(limit)
    Result.new(
      offers: ranked,
      minimum_price: offers.map(&:price).min,
      requested_minimum: minimum,
      requested_maximum: maximum,
      budget_detected: detected,
      floor_request: floor_request?,
      clarification_question: clarification_question(detected),
      exact_match: exact_match
    )
  end

  private

  attr_reader :business, :message, :preferences, :limit

  def offers
    @offers ||= business.products.active.order(:name).select { |product| eligible_product?(product) }.flat_map do |product|
      if product.product_variants.any?
        product.available_variants.map do |variant|
          Offer.new(product: product, variant: variant, price: variant.price, stock_quantity: variant.stock_quantity)
        end
      elsif product.stock_quantity.positive?
        [ Offer.new(product: product, variant: nil, price: product.price, stock_quantity: product.stock_quantity) ]
      else
        []
      end
    end
  end

  def price_bounds
    text = normalize_digits(message.downcase)
    numbers = text.scan(/\d+(?:\.\d+)?/).map(&:to_d)
    if text.match?(/(?:-|–|to|theke|থেকে)/) && numbers.length >= 2
      return [ numbers.first, numbers.second, true ]
    end
    return [ numbers.first, nil, true ] if numbers.any? && text.match?(/\b(above|over|minimum|min|beshi)\b|বেশি|উপরে/)
    if numbers.any? && text.match?(/\b(under|below|within|max|budget|moddhe|less than)\b|মধ্যে|নিচে|বাজেট/)
      return [ nil, numbers.first, true ]
    end

    remembered_minimum = preferences["minimum_price"].presence&.to_d
    remembered_maximum = preferences["maximum_price"].presence&.to_d
    remembered = remembered_minimum.present? || remembered_maximum.present?
    [ remembered_minimum, remembered_maximum,
      remembered || text.match?(/\b(cheapest|lowest|starting price|price starts|kom dam|budget)\b|সবচেয়ে কম|কম দাম/) ]
  end

  def preference_score(offer)
    searchable = searchable_text(offer.product, offer.variant)
    preference_terms.count { |term| searchable.include?(term) } * 10 +
      structured_preference_terms.count { |term| searchable.include?(term) } * 18 +
      projection_preference_score(offer.product) +
      [ offer.stock_quantity, 20 ].min
  end

  def preferred_offer(product_options, minimum:, maximum:, exact_match:)
    unless exact_match
      return product_options.min_by { |offer| constraint_distance(offer, minimum:, maximum:) }
    end

    return product_options.max_by(&:price) if maximum.present?
    return product_options.min_by(&:price) if minimum.present?

    product_options.min_by(&:price)
  end

  def matches_price_direction?(offer)
    baseline_prices = Array(preferences["previous_recommendations"]).filter_map do |item|
      item.to_h.with_indifferent_access[:price].presence&.to_d
    end
    return true if baseline_prices.empty?
    return offer.price < baseline_prices.min if preferences["price_direction"] == "lower"
    return offer.price > baseline_prices.max if preferences["price_direction"] == "higher"

    true
  end

  def closest_candidates(minimum:, maximum:)
    return offers.sort_by { |offer| (offer.price - maximum).abs } if maximum.present?
    return offers.sort_by { |offer| (offer.price - minimum).abs } if minimum.present?

    offers
  end

  def constraint_distance(offer, minimum:, maximum:)
    return (offer.price - maximum).abs if maximum.present?
    return (offer.price - minimum).abs if minimum.present?

    0
  end

  def projection_preference_score(product)
    preference = preferences["projection_preference"]
    return 0 if preference.blank?

    rank = { "soft" => 1, "moderate" => 2, "strong" => 3, "very strong" => 4 }
      .fetch(product.product_attributes.to_h["projection"].to_s.downcase, 2)
    preference == "stronger" ? rank * 12 : (5 - rank) * 12
  end

  def preference_terms
    @preference_terms ||= message.downcase.scan(/[[:alpha:]]{3,}/).uniq - %w[
      anything something product products price budget under below above within want need suggest please
      chai den koto taka dame moddhe ache koren
    ]
  end

  def structured_preference_terms
    @structured_preference_terms ||= preferences.values_at(
      "audience", "performance", "scent_families", "occasions"
    ).flatten.compact.map(&:to_s).flat_map { |value| value.downcase.scan(/[[:alpha:]-]{3,}/) }.uniq
  end

  def matches_format?(product)
    return product.combo? if preferences["format"] == "combo"
    return !product.combo? if preferences["format"] == "single"

    true
  end

  def eligible_product?(product)
    matches_format?(product) &&
      !product.id.in?(Array(preferences["rejected_product_ids"]).map(&:to_i)) &&
      avoids_excluded_families?(product) &&
      acceptable_projection?(product)
  end

  def avoids_excluded_families?(product)
    excluded = Array(preferences["avoid_scent_families"]).map(&:downcase)
    return true if excluded.empty?

    searchable = searchable_text(product)
    excluded.none? { |family| searchable.include?(family) }
  end

  def acceptable_projection?(product)
    return true unless preferences["maximum_projection"] == "moderate"

    !product.product_attributes.to_h["projection"].to_s.downcase.in?(%w[strong very\ strong])
  end

  def searchable_text(product, variant = nil)
    [
      product.name, product.category, product.tags, product.short_description, product.description,
      product.benefits, product.suitable_for, product.product_attributes.to_h.flatten.join(" "),
      variant&.size, variant&.name
    ].compact.join(" ").downcase
  end

  def clarification_question(budget_detected)
    return if budget_detected
    return if preferences["price_direction"].present? || preferences["projection_preference"].present?
    dimensions = preference_dimensions
    return if dimensions.size >= 2
    return "Would you prefer one perfume or a combo with multiple fragrances?" if dimensions.empty?

    if preferences["format"].blank?
      return "To narrow it down, is this for daily use, office, an occasion, or a gift? You can also share your budget."
    end

    if preferences["format"] == "combo"
      "Who is the combo for, and do they prefer fresh, sweet, woody/oud, or long-lasting fragrances?"
    else
      "What style do you prefer: fresh/clean, sweet/fruity, floral, warm/spicy, or woody/oud? You can also tell me the occasion."
    end
  end

  def preference_dimensions
    {
      format: preferences["format"],
      audience: preferences["audience"],
      performance: preferences["performance"],
      scent_families: Array(preferences["scent_families"]).presence,
      occasions: Array(preferences["occasions"]).presence
    }.compact_blank.keys
  end

  def normalize_digits(value)
    value.tr("০১২৩৪৫৬৭৮৯", "0123456789")
  end

  def floor_request?
    message.downcase.match?(/\b(cheapest|lowest|starting price|price starts|kom dam)\b|সবচেয়ে কম|কম দাম/)
  end
end
