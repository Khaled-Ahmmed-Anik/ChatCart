class PendingOrder < ApplicationRecord
  belongs_to :conversation
  belongs_to :product, optional: true
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
    cancelled: 8
  }

  validates :quantity, numericality: { greater_than: 0, only_integer: true }, allow_nil: true

  def ready_for_confirmation?
    product.present? &&
      quantity.present? &&
      customer_name.present? &&
      phone.present? &&
      address.present?
  end

  def total_price
    return 0 if product.blank? || quantity.blank?

    product.price * quantity
  end
end
