class CatalogueProductMention
  def self.pattern(name)
    normalized = ConversationTextNormalizer.call(name)
    labels = [ normalized, normalized.pluralize ].uniq.map { |label| Regexp.escape(label) }
    suffix = normalized.match?(/\p{Bengali}\z/) ? "(?:টা|টি)?" : ""
    /(?:\A|\s)((?:#{labels.join('|')})#{suffix})(?=\z|\s)/
  end
end
