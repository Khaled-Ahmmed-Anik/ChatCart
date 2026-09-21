class WhatsappWebhookEventRecorder
  Result = Data.define(:event, :created)

  def initialize(payload:, event_type:, business:, sender_id:, phone_number_id:, external_event_id:)
    @payload = payload.to_h
    @event_type = event_type.to_s
    @business = business
    @sender_id = sender_id
    @phone_number_id = phone_number_id
    @external_event_id = external_event_id
  end

  def record
    existing = WhatsappWebhookEvent.find_by(external_event_id: external_event_id) if external_event_id.present?
    return Result.new(event: existing, created: false) if existing

    Result.new(event: WhatsappWebhookEvent.create!(attributes), created: true)
  rescue ActiveRecord::RecordNotUnique
    Result.new(event: WhatsappWebhookEvent.find_by!(external_event_id: external_event_id), created: false)
  end

  private

  attr_reader :payload, :event_type, :business, :sender_id, :phone_number_id, :external_event_id

  def attributes
    processable = event_type == "customer_text"
    {
      business: business,
      event_type: event_type,
      external_event_id: external_event_id,
      sender_id: sender_id,
      phone_number_id: phone_number_id,
      payload: payload,
      status: processable ? "received" : "ignored",
      processed_at: processable ? nil : Time.current
    }
  end
end
