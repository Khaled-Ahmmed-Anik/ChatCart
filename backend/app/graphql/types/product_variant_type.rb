module Types
  class ProductVariantType < BaseObject
    field :id, ID, null: false
    field :name, String, null: false
    field :size, String
    field :sku, String
    field :price, String, null: false
    field :stock_quantity, Integer, null: false
    field :active, Boolean, null: false
    field :position, Integer, null: false
  end
end
