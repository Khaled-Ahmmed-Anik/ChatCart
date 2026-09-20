module Types
  class ComboItemInput < BaseInputObject
    argument :id, ID, required: false
    argument :component_product_id, ID, required: true
    argument :quantity, Integer, required: false, default_value: 1
    argument :selection_group, String, required: false
    argument :required, Boolean, required: false, default_value: true
    argument :position, Integer, required: false, default_value: 0
  end
end
