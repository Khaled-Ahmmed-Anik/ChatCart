class FragrancePreferenceExtractor
  SCENT_FAMILIES = {
    "fresh" => %w[fresh clean citrus aquatic marine airy halka],
    "sweet" => %w[sweet vanilla gourmand caramel chocolate mishti],
    "fruity" => %w[fruity fruit berry berries cherry plum],
    "floral" => %w[floral flower rose jasmine],
    "woody" => %w[woody wood cedar sandalwood],
    "oud" => %w[oud arabian oriental middle-eastern],
    "spicy" => %w[spicy spice warm],
    "tobacco" => %w[tobacco smoky smoke]
  }.freeze

  OCCASIONS = {
    "office" => %w[office work professional meeting],
    "daily" => %w[daily everyday casual regular],
    "date" => %w[date romantic intimate],
    "party" => %w[party event celebration gathering],
    "formal" => %w[formal wedding special],
    "gift" => %w[gift birthday anniversary eid]
  }.freeze

  def initialize(message)
    @message = message.to_s.downcase.squish
  end

  def call(existing: {})
    preferences = existing.to_h.stringify_keys
    preferences["format"] = detected_format || preferences["format"]
    preferences["audience"] = detected_audience || preferences["audience"]
    preferences["scent_families"] = (Array(preferences["scent_families"]) + detected_values(SCENT_FAMILIES)).uniq
    preferences["occasions"] = (Array(preferences["occasions"]) + detected_values(OCCASIONS)).uniq
    preferences["performance"] = "long-lasting" if message.match?(/long[ -]?lasting|longevity|lasts? long|beshi khon|দীর্ঘস্থায়ী/)
    preferences.compact
  end

  private

  attr_reader :message

  def detected_format
    return "combo" if message.match?(/\b(combo|bundle|set|collection|multiple|variety)\b/)
    return "single" if message.match?(/\b(single|one perfume|one fragrance|specific one|ekta)\b|একটা/)
  end

  def detected_audience
    return "women" if message.match?(/\b(for her|women|woman|female|ladies|girl|apu|apa)\b|মহিলা|মেয়েদের/)
    return "men" if message.match?(/\b(for him|men|man|male|gents|boy|bhai)\b|পুরুষ|ছেলেদের/)
    return "unisex" if message.match?(/\bunisex\b/)
  end

  def detected_values(dictionary)
    dictionary.filter_map do |canonical, terms|
      canonical if terms.any? { |term| message.match?(/\b#{Regexp.escape(term)}\b/) }
    end
  end
end
