class FragrancePreferenceExtractor
  def initialize(message)
    @message = message.to_s.downcase.squish
  end

  def call(existing: {})
    preferences = existing.to_h.stringify_keys
    avoided_families = (Array(preferences["avoid_scent_families"]) + detected_avoided_families).uniq
    preferences["format"] = detected_format || preferences["format"]
    preferences["audience"] = detected_audience || preferences["audience"]
    preferences["avoid_scent_families"] = avoided_families
    preferences["scent_families"] = (Array(preferences["scent_families"]) +
      detected_values(Constants::Fragrance::SCENT_FAMILIES) - avoided_families).uniq
    preferences["occasions"] = (Array(preferences["occasions"]) +
      detected_values(Constants::Fragrance::OCCASIONS)).uniq
    preferences["performance"] = "long-lasting" if message.match?(/long[ -]?lasting|longevity|lasts? long|beshi khon|দীর্ঘস্থায়ী/)
    preferences["maximum_projection"] = "moderate" if message.match?(/not (too )?strong|don'?t want strong|halka|soft projection|overpowering (chai na|no)|(?:too )?strong (na|chai na|jeno na)/)
    preferences["price_direction"] = detected_price_direction || preferences["price_direction"]
    preferences["projection_preference"] = detected_projection_preference || preferences["projection_preference"]
    preferences.merge!(detected_budget)
    preferences.compact
  end

  def meaningful?
    extracted = call
    extracted.values_at(
      "format", "audience", "performance", "maximum_projection", "minimum_price", "maximum_price",
      "price_direction", "projection_preference", "scent_families", "avoid_scent_families", "occasions"
    ).any?(&:present?)
  end

  def refinement?
    detected_price_direction.present? || detected_projection_preference.present? ||
      message.match?(/\b(more|less|kom|beshi|aro)\b.*\b(fresh|sweet|fruity|floral|woody|oud|spicy|long[ -]?lasting)\b/)
  end

  private

  attr_reader :message

  def detected_format
    return "combo" if message.match?(/\b(combo|bundle|set|collection|multiple|variety)\b/)
    "single" if message.match?(/\b(single|one perfume|one fragrance|specific one|ekta)\b|একটা/)
  end

  def detected_audience
    return "women" if message.match?(/\b(for her|women|woman|female|ladies|girl|apu|apa)\b|মহিলা|মেয়েদের/)
    return "men" if message.match?(/\b(for him|men|man|male|gents|boy|bhai)\b|পুরুষ|ছেলেদের/)
    "unisex" if message.match?(/\bunisex\b/)
  end

  def detected_price_direction
    return "lower" if message.match?(/\b(cheaper|less expensive|lower price|kom dam|aro kom)\b|সস্তা|কম দাম/)
    "higher" if message.match?(/\b(more expensive|premium|higher price|budget barate|aro dami)\b/)
  end

  def detected_projection_preference
    return "stronger" if message.match?(/\b(stronger|more strong|beshi strong|aro strong|more noticeable)\b/)
    "softer" if message.match?(/\b(softer|less strong|less projection|kom strong|aro halka|subtle)\b/)
  end

  def detected_values(dictionary)
    dictionary.filter_map do |canonical, terms|
      canonical if terms.any? { |term| message.match?(/\b#{Regexp.escape(term)}\b/) }
    end
  end

  def detected_avoided_families
    Constants::Fragrance::SCENT_FAMILIES.filter_map do |canonical, terms|
      canonical if terms.any? do |term|
        escaped = Regexp.escape(term)
        message.match?(/\b(?:not|without|avoid|don'?t like|chai na|pochondo na)\b.{0,20}\b#{escaped}\b/) ||
          message.match?(/\bno\b.{0,5}\b#{escaped}\b/) ||
          message.match?(/\b(?:less|kom)\b.{0,10}\b#{escaped}\b/) ||
          message.match?(/\b#{escaped}\b.{0,10}\b(?:less|kom)\b/) ||
          message.match?(/\b#{escaped}\b.{0,10}(?:chai na|pochondo na|jeno na hoy|not wanted)/)
      end
    end
  end

  def detected_budget
    text = message.tr("০১২৩৪৫৬৭৮৯", "0123456789")
    numbers = text.scan(/\d+(?:\.\d+)?/).map(&:to_d)
    return { "minimum_price" => numbers.first, "maximum_price" => numbers.second } if numbers.length >= 2 && text.match?(/-|–| to | theke |থেকে/)
    return { "maximum_price" => numbers.first } if numbers.any? && text.match?(/under|below|within|budget|max|moddhe|less than|মধ্যে|নিচে|বাজেট/)
    return { "minimum_price" => numbers.first } if numbers.any? && text.match?(/above|over|minimum|min|beshi|বেশি|উপরে/)

    {}
  end
end
