class Conversation < ApplicationRecord
  has_many :messages, dependent: :destroy
  has_many :pending_orders, dependent: :destroy

  enum :status, {
    active: 0,
    handed_over: 1,
    closed: 2
  }

  validates :external_customer_id, presence: true
  validates :channel, presence: true

  def pending_order
    pending_orders.order(created_at: :desc, id: :desc).first
  end

  def create_pending_order!(attributes = {})
    pending_orders.create!(attributes)
  end
end
