class WhatsappDelivery < ApplicationRecord
  belongs_to :whatsapp_webhook_event
  belongs_to :message

  validates :recipient_id, :phone_number_id, presence: true
  validates :status, inclusion: { in: Constants::Meta::DELIVERY_STATUSES }
  validates :attempts, numericality: { greater_than_or_equal_to: 0 }
  validates :message_id, uniqueness: true
end
