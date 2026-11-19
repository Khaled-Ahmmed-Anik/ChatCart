class ConversationLanguagePreference
  def self.explicit(text)
    normalized = ConversationTextNormalizer.call(text)
    return unless normalized.match?(Constants::Conversation::LANGUAGE_REQUEST)
    return "banglish" if normalized.match?(/\bbanglish\b/)
    return "bengali" if normalized.match?(/\b(?:bangla|bengali)\b/)

    "english" if normalized.match?(/\benglish\b/)
  end

  def self.detect(text)
    return "bengali" if text.to_s.match?(/\p{Bengali}/)
    "banglish" if ConversationTextNormalizer.call(text).match?(Constants::Conversation::BANGLISH_CUES)
  end

  def self.choose(text, state, interpretation: nil)
    remembered = state["preferred_language"] if state["language_explicit"] || text.to_s.split.size <= 2
    explicit(text) || remembered || detect(text) ||
      (interpretation&.confidence.to_f >= 0.7 ? interpretation.language : nil) || state.fetch("preferred_language", "english")
  end

  def self.remember!(conversation, text)
    state = conversation.conversation_state.to_h
    language = choose(text, state)
    updated = state.merge("preferred_language" => language)
    updated["language_explicit"] = true if explicit(text)
    conversation.update!(conversation_state: updated) unless updated == state
  end
end
