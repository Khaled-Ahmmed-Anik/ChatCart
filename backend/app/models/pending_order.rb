class PendingOrder < ApplicationRecord
  belongs_to :conversation
  belongs_to :product, optional: true
  belongs_to :product_variant, optional: true
  has_one :order, dependent: :restrict_with_error

  enum :status, {
    collecting_product: 0,
    collecting_quantity: 1,
    collecting_name: 2,
    collecting_phone: 3,
    collecting_address: 4,
    awaiting_confirmation: 5,
    confirmed: 6,
    submitted_to_woocommerce: 7,
    cancelled: 8,
    collecting_variant: 9
  }

  validates :quantity, numericality: { greater_than: 0, only_integer: true }, allow_nil: true

  def ready_for_confirmation?
    product.present? && variant_selected_if_required? &&
      quantity.present? &&
      customer_name.present? &&
      phone.present? &&
      address.present?
  end

  def total_price
    return 0 if product.blank? || quantity.blank?

    unit_price * quantity
  end

  def unit_price
    product_variant&.price || product&.price || 0
  end

  def variant_selected_if_required?
    product.blank? || product.product_variants.none? || product_variant.present?
  end

  def product_variants_required?
    product&.available_variants&.any?
  end
end
