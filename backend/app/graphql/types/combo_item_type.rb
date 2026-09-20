module Types
  class ComboItemType < BaseObject
    field :id, ID, null: false
    field :component_product, ProductType, null: false
    field :quantity, Integer, null: false
    field :selection_group, String
    field :required, Boolean, null: false
    field :position, Integer, null: false
  end
end
