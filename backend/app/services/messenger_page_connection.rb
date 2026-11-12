class MessengerPageConnection
  def self.for_event(event)
    page_id = event.payload["chatcart_page_id"].presence || event.payload.dig("recipient", "id").presence
    if page_id.blank? && event.payload["source"] == "seller_dashboard"
      incoming = event.business.messenger_webhook_events.where(sender_id: event.sender_id, event_type: %w[customer_text customer_image]).order(id: :desc).first
      return for_event(incoming) if incoming
    end
    return if page_id.blank?

    event.business.channel_connections.active.find_by(channel: "facebook", external_account_id: page_id)
  end
end
