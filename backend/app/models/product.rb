class Product < ApplicationRecord
  belongs_to :business, default: -> { Business.default }

  scope :active, -> { where(active: true) }
  scope :in_stock, -> { where("stock_quantity > 0") }

  validates :name, presence: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }
  validates :stock_quantity, numericality: { greater_than_or_equal_to: 0, only_integer: true }

  def available_for_quantity?(requested_quantity)
    requested_quantity.to_i.positive? && active? && stock_quantity >= requested_quantity.to_i
  end
end
