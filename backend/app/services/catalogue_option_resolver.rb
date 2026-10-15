class CatalogueOptionResolver
  def self.call(product:, text:)
    normalized = normalize(text)
    aliases = product.product_attributes.to_h.fetch("option_aliases", {}).to_h
    matches = product.available_variants.select do |variant|
      labels = [ variant.name, variant.size, *Array(aliases[variant.name]) ].compact
      labels.any? do |label|
        token = Regexp.escape(normalize(label))
        normalized.match?(/(?:\A|\s)#{token}(?:\z|\s)/) &&
          !normalized.match?(/(?:\A|\s)#{token}\s+(?:na|no|not)(?:\z|\s)/)
      end
    end
    matches.first if matches.one?
  end

  def self.normalize(text)
    ConversationTextNormalizer.call(text).gsub(/\bmedium\b/, "m")
      .gsub(/\bsmall\b/, "s").gsub(/\blarge\b/, "l")
      .gsub(/\b(?:metres?|meters?)\b/, "metre").squish
  end
end
