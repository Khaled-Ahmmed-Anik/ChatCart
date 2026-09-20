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
    field :product_type, String, null: false
    field :stock_strategy, String, null: false
    field :aliases, [ String ], null: false
    field :image_urls, [ String ], null: false
    field :source_url, String
    field :archived_at, GraphQL::Types::ISO8601DateTime
    field :variants, [ ProductVariantType ], null: false
    field :combo_items, [ ComboItemType ], null: false

    def variants
      object.product_variants
    end
  end
end
