class ConversationEntityValidator
  # The model proposes values; only values supported by this turn can mutate checkout.
  def self.call(interpretation, content)
    return interpretation if interpretation.blank?

    normalized = ConversationTextNormalizer.call(content)
    entities = interpretation.entities.to_h.with_indifferent_access.select do |key, value|
      case key.to_s
      when "product_name", "variant_name", "size", "customer_name", "address"
        candidate = ConversationTextNormalizer.call(value)
        candidate.present? && normalized.include?(candidate)
      when "phone"
        content.to_s.gsub(/\D/, "").include?(value.to_s.gsub(/\D/, "")) && value.to_s.gsub(/\D/, "").present?
      when "quantity"
        quantity_supported?(normalized, value)
      else
        true
      end
    end
    interpretation.with(entities: entities.with_indifferent_access)
  end

  def self.quantity_supported?(normalized, value)
    quantity = value.to_i
    return false unless quantity.positive?

    words = Constants::Conversation::NUMBER_WORDS.select { |_word, number| number == quantity }.keys
    labels = ([ quantity.to_s ] + words).map { |label| Regexp.escape(label) }.join("|")
    normalized.match?(/\b(?:#{labels})\b(?!\s*(?:ml|kg|gm|days?|din|hours?|taka|tk)\b)/)
  end
end
