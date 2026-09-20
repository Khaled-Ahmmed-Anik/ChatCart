module Types
  class ProductVariantInput < BaseInputObject
    argument :id, ID, required: false
    argument :name, String, required: true
    argument :size, String, required: false
    argument :sku, String, required: false
    argument :price, String, required: true
    argument :stock_quantity, Integer, required: true
    argument :active, Boolean, required: false, default_value: true
    argument :position, Integer, required: false, default_value: 0
  end
end
