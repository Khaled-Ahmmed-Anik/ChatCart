module Types
  class ProductInput < BaseInputObject
    argument :name, String, required: true
    argument :price, String, required: true
    argument :stock_quantity, Integer, required: true
    argument :description, String, required: false
    argument :short_description, String, required: false
    argument :category, String, required: false
    argument :benefits, String, required: false
    argument :usage_instructions, String, required: false
    argument :suitable_for, String, required: false
    argument :product_attributes, GraphQL::Types::JSON, required: false
    argument :tags, String, required: false
    argument :active, Boolean, required: false, default_value: true
    argument :woo_commerce_product_id, String, required: false
    argument :variants, [ ProductVariantInput ], required: false
  end
end
