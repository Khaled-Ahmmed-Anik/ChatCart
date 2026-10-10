class PendingOrderItem < ApplicationRecord
  belongs_to :pending_order
  belongs_to :product
  belongs_to :product_variant, optional: true

  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validate :catalogue_ownership

  def unit_price = product_variant&.price || product.price
  def total_price = unit_price * quantity
  def label = [ product.name, product_variant&.display_name ].compact.join(" ")
  def available?
    product.business_id == pending_order.conversation.business_id && product.active? && !product.archived? &&
      (product_variant.blank? || product_variant.product_id == product_id) &&
      (product.product_variants.none? || product_variant.present?) &&
      (product_variant || product).available_for_quantity?(quantity)
  end

  private

  def catalogue_ownership
    return if product.blank? || pending_order.blank?

    errors.add(:product, "belongs to another business") if product.business_id != pending_order.conversation.business_id
    if product_variant.present? && product_variant.product_id != product_id
      errors.add(:product_variant, "belongs to another product")
    end
  end
end
