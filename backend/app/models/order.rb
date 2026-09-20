class Order < ApplicationRecord
  STATUSES = %w[confirmed revision_pending processing submitted delivered cancelled].freeze

  belongs_to :business
  belongs_to :conversation
  belongs_to :pending_order
  has_many :order_items, dependent: :destroy
  has_many :delivery_submissions, dependent: :destroy

  validates :number, :customer_name, :phone, :address, :currency, presence: true
  validates :number, uniqueness: { scope: :business_id }
  validates :status, inclusion: { in: STATUSES }

  scope :recent_first, -> { order(confirmed_at: :desc, id: :desc) }
end
