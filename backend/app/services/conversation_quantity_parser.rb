class ConversationQuantityParser
  def self.call(text, products: [])
    normalized = text.to_s.downcase.tr("০১২৩৪৫৬৭৮৯", "0123456789")
    return if normalized.match?(/(?:\A|\s)-\s*\d/)
    return if normalized.match?(/\d+\.\d+\s*(?:pcs?|pieces?|units?|ta|টি|টা)\b/i)

    labels = products.flat_map(&:searchable_names).sort_by { |label| -label.length }
    labels.each do |label|
      normalized = normalized.gsub(/(?<![\p{L}\p{N}])#{Regexp.escape(label.downcase.strip)}(?![\p{L}\p{N}])/u, " ")
    end
    normalized = normalized.gsub(/\b(?:first|second|third|last|previous|prothom|ditiyo)\s+one\b/, " ")
      .gsub(/\b[a-z]+\d+[a-z0-9]*\b/i, " ")
      .gsub(/\b01[3-9]\d{8}\b/, " ")
      .gsub(/\b\d+(?:\.\d+)?\s*(?:ml|mah|watts?|w|kg|gm|gb|hours?|days?|din|ghonta|taka|tk)\b/i, " ")
    units = /(?:ta|ti|pieces?|pcs?|bottles?|units?|টি|টা)/i
    explicit = normalized.match(/(?<![\p{L}\p{N}])(\d+)\s*#{units}(?![\p{L}\p{N}])/u)
    return explicit[1].to_i if explicit && explicit[1].to_i.positive?

    Constants::Conversation::NUMBER_WORDS.each do |word, number|
      return number if normalized.match?(/(?<![\p{L}\p{N}])#{Regexp.escape(word)}(?![\p{L}\p{N}])(?!\s*(?:days?|din|hours?|ghonta|taka|tk|ml|kg|gm)\b)/u)
    end
    normalized = normalized.strip.sub(/[.!?]+\z/, "").strip
    match = normalized.match(/\A(?:actually[\s,]*)?(?:(?:change|update|make)\s+)?(?:(?:the\s+)?quantity\s*)?(?:it\s+|to\s+)?(\d+)\s*\z/i)
    match[1].to_i if match && match[1].to_i.positive?
  end
end
