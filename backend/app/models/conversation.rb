class Conversation < ApplicationRecord
  has_many :messages, dependent: :destroy
  has_one :pending_order, dependent: :destroy

  enum :status, {
    active: 0,
    handed_over: 1,
    closed: 2
  }

  validates :external_customer_id, presence: true
  validates :channel, presence: true
end
