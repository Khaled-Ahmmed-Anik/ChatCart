class ComboItem < ApplicationRecord
  belongs_to :combo_product, class_name: "Product", inverse_of: :combo_items
  belongs_to :component_product, class_name: "Product"

  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validate :combo_cannot_include_itself
  validate :component_belongs_to_same_business

  private

  def combo_cannot_include_itself
    errors.add(:component_product, "cannot be the combo itself") if combo_product_id == component_product_id
  end

  def component_belongs_to_same_business
    return if combo_product.blank? || component_product.blank? || combo_product.business_id == component_product.business_id

    errors.add(:component_product, "must belong to the same business")
  end
end
