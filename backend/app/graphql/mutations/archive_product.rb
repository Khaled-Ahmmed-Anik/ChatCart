module Mutations
  class ArchiveProduct < BaseMutation
    argument :id, ID, required: true
    argument :permanent, Boolean, required: false, default_value: false

    field :deleted, Boolean, null: false
    field :product, Types::ProductType
    field :errors, [ String ], null: false

    def resolve(id:, permanent:)
      require_management_role!
      product = context[:current_business].products.find(id)
      if permanent
        return { deleted: false, product: product, errors: [ "Products used by orders or combos can only be archived" ] } unless product.deletable?

        product.destroy!
        { deleted: true, product: nil, errors: [] }
      else
        product.archive!
        { deleted: false, product: product, errors: [] }
      end
    end
  end
end
