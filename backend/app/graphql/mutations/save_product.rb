module Mutations
  class SaveProduct < BaseMutation
    argument :id, ID, required: false
    argument :input, Types::ProductInput, required: true

    field :product, Types::ProductType
    field :errors, [ String ], null: false

    def resolve(input:, id: nil)
      require_management_role!
      product = id ? context[:current_business].products.find(id) : context[:current_business].products.new

      attributes = input.to_h
      variants = attributes.delete(:variants)
      combo_items = attributes.delete(:combo_items)
      if variants
        submitted_ids = variants.filter_map { |variant| variant[:id]&.to_i }
        removed = product.product_variants.where.not(id: submitted_ids).map do |variant|
          { id: variant.id, _destroy: true }
        end
        attributes[:product_variants_attributes] = variants + removed
      end
      if combo_items
        submitted_ids = combo_items.filter_map { |item| item[:id]&.to_i }
        removed = product.combo_items.where.not(id: submitted_ids).map { |item| { id: item.id, _destroy: true } }
        attributes[:combo_items_attributes] = combo_items + removed
      end

      if product.update(attributes)
        { product: product, errors: [] }
      else
        { product: nil, errors: product.errors.full_messages }
      end
    end
  end
end
