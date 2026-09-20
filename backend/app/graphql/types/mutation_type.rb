module Types
  class MutationType < BaseObject
    field :save_product, mutation: Mutations::SaveProduct
  end
end
