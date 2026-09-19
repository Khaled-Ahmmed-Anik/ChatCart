class MessengerWebhookEventRecorder
  Result = Data.define(:event, :created)

  def initialize(payload:, event_type:)
    @payload = if payload.respond_to?(:to_unsafe_h)
      payload.to_unsafe_h.with_indifferent_access
    else
      payload.to_h.with_indifferent_access
    end
    @event_type = event_type.to_s
  end

  def record
    existing_event = MessengerWebhookEvent.find_by(external_event_id: external_event_id) if external_event_id.present?
    return Result.new(event: existing_event, created: false) if existing_event

    event = MessengerWebhookEvent.create!(attributes)
    Result.new(event: event, created: true)
  rescue ActiveRecord::RecordNotUnique
    Result.new(event: MessengerWebhookEvent.find_by!(external_event_id: external_event_id), created: false)
  end

  private

  attr_reader :payload, :event_type

  def attributes
    {
      event_type: event_type,
      external_event_id: external_event_id,
      sender_id: payload.dig(:sender, :id),
      payload: payload,
      status: event_type == "customer_text" ? "received" : "ignored",
      processed_at: event_type == "customer_text" ? nil : Time.current
    }
  end

  def external_event_id
    payload.dig(:message, :mid).presence
  end
end
