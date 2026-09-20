class OrderItem < ApplicationRecord
  belongs_to :order
  belongs_to :product, optional: true
  belongs_to :product_variant, optional: true

  validates :product_name, presence: true
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
end
