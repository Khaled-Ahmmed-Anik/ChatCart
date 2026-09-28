class WhatsappWebhookEvent < ApplicationRecord
  belongs_to :business
  has_one :whatsapp_delivery, dependent: :destroy

  validates :event_type, inclusion: { in: Constants::Meta::WHATSAPP_EVENT_TYPES }
  validates :status, inclusion: { in: Constants::Meta::WEBHOOK_EVENT_STATUSES }
  validates :external_event_id, uniqueness: true, allow_nil: true
end
