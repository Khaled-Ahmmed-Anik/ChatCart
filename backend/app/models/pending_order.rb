class PendingOrder < ApplicationRecord
  belongs_to :conversation
  belongs_to :product, optional: true
  belongs_to :product_variant, optional: true
  has_one :order, dependent: :restrict_with_error
  has_many :pending_order_items, dependent: :destroy

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
    line_items.sum(&:total_price)
  end

  def line_items
    items = pending_order_items.includes(:product, :product_variant).to_a
    if product.present? && quantity.present? && variant_selected_if_required?
      current = PendingOrderItem.new(pending_order: self, product: product, product_variant: product_variant, quantity: quantity)
      existing = items.find { |item| item.product_id == current.product_id && item.product_variant_id == current.product_variant_id }
      existing ? existing.quantity += quantity : items << current
    end
    items
  end

  def inventory_available? = line_items.present? && line_items.all?(&:available?)

  def item_snapshot
    line_items.map do |item|
      { "product_id" => item.product_id, "product_name" => item.product.name,
        "variant_id" => item.product_variant_id, "variant_name" => item.product_variant&.display_name,
        "quantity" => item.quantity, "unit_price" => item.unit_price.to_s, "total_price" => item.total_price.to_s }.compact
    end
  end

  def save_current_item!
    return unless product.present? && quantity.present? && variant_selected_if_required?

    item = pending_order_items.find_or_initialize_by(product: product, product_variant: product_variant)
    item.quantity = item.quantity.to_i + quantity
    item.save!
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
