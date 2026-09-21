class ConversationIntentRegistry
  def self.valid?(intent)
    intent.to_s.in?(intents)
  end

  def self.intents
    Constants::Intents::ALL
  end

  def self.mutating_intents
    Constants::Intents::MUTATING
  end

  def self.informational_intents
    Constants::Intents::INFORMATIONAL
  end
end
