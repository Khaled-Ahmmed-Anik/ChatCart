class MessengerPhotoTurn
  WINDOW = 3.seconds
  PHOTO_REFERENCE = /\b(?:this|that|photo|picture|image|eta|eita)\b|এইটা|এইটার|এটা|ছবি/i

  def self.caption_candidate?(text)
    text.to_s.match?(PHOTO_REFERENCE) && text.to_s.match?(Constants::PhotoRecognition::ORDER_REQUEST) &&
      !text.to_s.match?(Constants::PhotoRecognition::ORDER_NEGATION) && !text.to_s.match?(/[?？]/)
  end

  def self.companion(event)
    return if event.event_type == "customer_image" && event.payload.dig("message", "text").present?

    other_type = event.event_type == "customer_image" ? "customer_text" : "customer_image"
    return unless other_type == "customer_text" || caption_candidate?(event.payload.dig("message", "text"))

    neighbors = event.business.messenger_webhook_events.processable.where(sender_id: event.sender_id)
      .where(created_at: (event.created_at - WINDOW)..(event.created_at + WINDOW)).where.not(id: event.id).to_a
    return unless neighbors.one?

    candidate = neighbors.first
    return unless candidate.event_type == other_type && candidate.status.in?(%w[received failed])
    text = other_type == "customer_text" ? candidate : event
    candidate if caption_candidate?(text.payload.dig("message", "text"))
  end
end
