module Mutations
  class SaveProduct < BaseMutation
    argument :id, ID, required: false
    argument :input, Types::ProductInput, required: true

    field :product, Types::ProductType
    field :errors, [ String ], null: false

    def resolve(input:, id: nil)
      require_management_role!
      product = id ? context[:current_business].products.find(id) : context[:current_business].products.new

      if product.update(input.to_h)
        { product: product, errors: [] }
      else
        { product: nil, errors: product.errors.full_messages }
      end
    end
  end
end
