class ProductVariant < ApplicationRecord
  belongs_to :product

  after_commit :refresh_business_knowledge

  scope :active, -> { where(active: true) }
  scope :in_stock, -> { where("stock_quantity > 0") }
  scope :available, -> { active.in_stock }

  validates :name, presence: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }
  validates :stock_quantity, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validates :sku, uniqueness: { scope: :product_id }, allow_blank: true

  def available_for_quantity?(quantity)
    quantity.to_i.positive? && active? && stock_quantity >= quantity.to_i
  end

  def display_name
    size.presence || name
  end

  private

  def refresh_business_knowledge
    SyncBusinessKnowledgeJob.perform_later(product.business_id)
  end
end
