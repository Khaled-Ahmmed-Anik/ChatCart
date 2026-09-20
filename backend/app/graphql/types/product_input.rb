module Types
  class ProductInput < BaseInputObject
    argument :name, String, required: true
    argument :price, String, required: true
    argument :stock_quantity, Integer, required: true
    argument :description, String, required: false
    argument :tags, String, required: false
    argument :active, Boolean, required: false, default_value: true
    argument :woo_commerce_product_id, String, required: false
  end
end
