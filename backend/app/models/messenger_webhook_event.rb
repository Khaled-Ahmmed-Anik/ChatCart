class MessengerWebhookEvent < ApplicationRecord
  EVENT_TYPES = %w[
    customer_text message_echo delivery read postback attachment malformed_message unknown
  ].freeze
  STATUSES = %w[received processing processed ignored failed].freeze

  has_one :messenger_delivery, dependent: :destroy

  validates :event_type, inclusion: { in: EVENT_TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :external_event_id, uniqueness: true, allow_nil: true

  scope :processable, -> { where(event_type: "customer_text") }
end
