class MessengerWebhookEvent < ApplicationRecord
  belongs_to :business, default: -> { Business.default }
  EVENT_TYPES = %w[
    customer_text customer_image message_echo delivery read postback attachment malformed_message unknown
  ].freeze
  STATUSES = %w[received processing processed ignored failed].freeze

  has_one :messenger_delivery, dependent: :destroy

  validates :event_type, inclusion: { in: EVENT_TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :external_event_id, uniqueness: true, allow_nil: true

  scope :processable, -> { where(event_type: Constants::Meta::MESSENGER_PROCESSABLE_EVENT_TYPES) }
end
