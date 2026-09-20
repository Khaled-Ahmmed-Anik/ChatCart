module Types
  class ProductType < BaseObject
    field :id, ID, null: false
    field :name, String, null: false
    field :description, String
    field :short_description, String
    field :category, String
    field :benefits, String
    field :usage_instructions, String
    field :suitable_for, String
    field :product_attributes, GraphQL::Types::JSON, null: false
    field :price, String, null: false
    field :stock_quantity, Integer, null: false
    field :tags, String
    field :active, Boolean, null: false
    field :woo_commerce_product_id, String
    field :variants, [ ProductVariantType ], null: false

    def variants
      object.product_variants
    end
  end
end
