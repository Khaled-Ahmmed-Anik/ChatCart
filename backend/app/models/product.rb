class Product < ApplicationRecord
  belongs_to :business, default: -> { Business.default }
  has_many :product_variants, -> { order(:position, :id) }, dependent: :destroy
  accepts_nested_attributes_for :product_variants, allow_destroy: true

  scope :active, -> { where(active: true) }
  scope :in_stock, -> { where("stock_quantity > 0") }

  validates :name, presence: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }
  validates :stock_quantity, numericality: { greater_than_or_equal_to: 0, only_integer: true }

  def available_for_quantity?(requested_quantity)
    return product_variants.available.any? { |variant| variant.available_for_quantity?(requested_quantity) } if product_variants.any?

    requested_quantity.to_i.positive? && active? && stock_quantity >= requested_quantity.to_i
  end

  def available_variants
    product_variants.available
  end

  def starting_price
    available_variants.minimum(:price) || price
  end

  def total_available_stock
    product_variants.any? ? available_variants.sum(:stock_quantity) : stock_quantity
  end
end
