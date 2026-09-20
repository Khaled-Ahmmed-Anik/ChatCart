class MessengerDelivery < ApplicationRecord
  STATUSES = %w[pending retrying delivered failed skipped].freeze

  belongs_to :messenger_webhook_event
  belongs_to :message

  validates :recipient_id, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :attempts, numericality: { greater_than_or_equal_to: 0 }
  validates :message_id, uniqueness: true
end
