class ConversationAddressPreference
  PREFERENCES = {
    "bhai" => [ /\A[\s,!-]*(?:hi|hello|hey)?[\s,!-]*bhai\b/i, /\bbhai[\s!.?]*\z/i, /\bcall me bhai\b/i,
      /\A[\s,!-]*ভাই/, /ভাই[\s!.?]*\z/ ],
    "apu" => [ /\A[\s,!-]*(?:hi|hello|hey)?[\s,!-]*apu\b/i, /\bapu[\s!.?]*\z/i, /\bcall me apu\b/i,
      /\A[\s,!-]*আপু/, /আপু[\s!.?]*\z/ ],
    "sir" => [ /\A[\s,!-]*(?:hi|hello|hey)?[\s,!-]*sir\b/i, /\bsir[\s!.?]*\z/i, /\bcall me sir\b/i,
      /\A[\s,!-]*স্যার/, /স্যার[\s!.?]*\z/ ],
    "ma'am" => [ /\A[\s,!-]*(?:hi|hello|hey)?[\s,!-]*(?:ma['’]?am|madam|mam)\b/i,
      /\b(?:ma['’]?am|madam|mam)[\s!.?]*\z/i, /\bcall me (?:ma['’]?am|madam|mam)\b/i,
      /\A[\s,!-]*(?:ম্যাম|ম্যাডাম)/, /(?:ম্যাম|ম্যাডাম)[\s!.?]*\z/ ]
  }.freeze

  def self.detect(content)
    normalized = content.to_s.squish
    PREFERENCES.find { |_preference, patterns| patterns.any? { |pattern| normalized.match?(pattern) } }&.first
  end

  def self.display(preference)
    {
      "bhai" => "bhai",
      "apu" => "apu",
      "sir" => "sir",
      "ma'am" => "ma’am"
    }[preference]
  end
end
