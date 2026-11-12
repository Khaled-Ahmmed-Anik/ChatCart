class CatalogueBudgetParser
  NUMBER = /\d+(?:\.\d+)?/
  MAXIMUM = /(?:\b(?:under|below|within|max|budget|less than)\b|বাজেট)\s*(?:is|of|:)?\s*(?:৳|tk\.?|bdt)?\s*(#{NUMBER})(?![\w.])/i
  MINIMUM = /\b(?:above|over|minimum|min)\b\s*(?:৳|tk\.?|bdt)?\s*(#{NUMBER})(?![\w.])/i
  SUFFIX_MAXIMUM = /(?<![\w.])(#{NUMBER})\s*(?:৳|tk\.?|bdt|takar?|টাকার?)?\s*(?:er\s+)?(?:under\b|below\b|moddhe|মধ্যে|নিচে)/i
  RANGE = /(?<![\w.])(#{NUMBER})\s*(?:৳|tk|bdt|taka|টাকা)?\s*(?:-|–|\bto\b|\btheke\b|থেকে)\s*(#{NUMBER})(?![\w.])/i

  def self.call(message)
    text = message.to_s.downcase.tr("০১২৩৪৫৬৭৮৯", "0123456789").gsub(/(?<=\d),(?=\d{3}\b)/, "")
    # Specifications and model numbers are not monetary amounts.
    text = text.gsub(/\b\d+(?:\.\d+)?\s*(?:w|watts?|v|mah|ml|gb|tb|hz|mm|inch(?:es)?)\b/i, " ")
    if (match = RANGE.match(text))
      return { "minimum_price" => match[1].to_d, "maximum_price" => match[2].to_d }
    end
    if (match = MAXIMUM.match(text) || SUFFIX_MAXIMUM.match(text))
      return { "maximum_price" => match[1].to_d }
    end
    if (match = MINIMUM.match(text))
      return { "minimum_price" => match[1].to_d }
    end
    {}
  end
end
