class ConversationTextNormalizer
  def self.call(value)
    value.to_s.downcase.unicode_normalize(:nfkc).tr("০১২৩৪৫৬৭৮৯", "0123456789")
      .gsub(/[^\p{L}\p{N}]+/u, " ").squish.split.map do |word|
        Constants::Conversation::BANGLISH_WORDS.fetch(word, word)
      end.join(" ")
  end
end
