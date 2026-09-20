module Types
  class ProductType < BaseObject
    field :id, ID, null: false
    field :name, String, null: false
    field :description, String
    field :price, String, null: false
    field :stock_quantity, Integer, null: false
    field :tags, String
    field :active, Boolean, null: false
    field :woo_commerce_product_id, String
  end
end
