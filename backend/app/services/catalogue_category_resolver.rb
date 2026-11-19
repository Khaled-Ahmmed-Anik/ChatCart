class CatalogueCategoryResolver
  def self.call(business:, text:, previous_categories: [])
    normalized = normalize(text)
    categories = business.products.available_for_sale.where.not(category: [ nil, "" ]).distinct.pluck(:category)
    matches = categories.select do |category|
      label = normalize(category)
      normalized.match?(/(?:\A|\s)#{Regexp.escape(label)}(?:\z|\s)/) &&
        !normalized.match?(/\b(?:not|no|without|avoid|bad)\s+(?:a\s+)?#{Regexp.escape(label)}\b|\b#{Regexp.escape(label)}\s+(?:na|not|no)\b/)
    end
    if normalized.match?(Constants::Catalogue::ACCESSORY_WORDS) &&
        !normalized.match?(/\b(?:not|no|without|avoid)\s+(?:protective\s+)?(?:case|cover|accessor(?:y|ies))\b|\bcover\s+chai\s+na\b/)
      accessories = categories.select { |category| category.match?(/accessor|case|cover/i) }
      matches = accessories if accessories.one?
    end
    if matches.any?
      return matches.reject do |category|
        matches.any? { |other| other != category && normalize(other).start_with?("#{normalize(category)} ") }
      end
    end
    return [] unless normalized.match?(/\A[a-z]{#{Constants::Catalogue::MINIMUM_CATEGORY_TYPO_LENGTH},}\z/)

    # Only repair a short follow-up against the category already discussed.
    categories.select do |category|
      previous_categories.include?(category) && one_edit_apart?(normalized, normalize(category))
    end.then { |candidates| candidates.one? ? candidates : [] }
  end

  def self.normalize(text)
    ConversationTextNormalizer.call(text).split.map(&:singularize).join(" ")
  end

  def self.rejected_categories(business:, text:)
    normalized = normalize(text)
    business.products.available_for_sale.where.not(category: [ nil, "" ]).distinct.pluck(:category).select do |category|
      label = Regexp.escape(normalize(category))
      normalized.match?(/\b(?:not|no|without|avoid|bad)\s+(?:a\s+)?#{label}\b|\b#{label}\s+(?:na|not|no)\b/)
    end
  end

  def self.one_edit_apart?(left, right)
    return false if (left.length - right.length).abs > 1

    if left.length == right.length
      return left.chars.zip(right.chars).count { |a, b| a != b } == 1
    end
    shorter, longer = [ left, right ].sort_by(&:length)
    longer.length.times.any? { |index| longer[0...index] + longer[(index + 1)..] == shorter }
  end
end
