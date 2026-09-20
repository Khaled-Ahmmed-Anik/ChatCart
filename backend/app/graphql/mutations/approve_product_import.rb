module Mutations
  class ApproveProductImport < BaseMutation
    argument :draft_id, ID, required: true

    field :product, Types::ProductType
    field :errors, [ String ], null: false

    def resolve(draft_id:)
      require_management_role!
      draft = context[:current_business].product_import_drafts.find(draft_id)
      product = ProductImportApprover.new(draft: draft).approve!
      { product: product, errors: [] }
    rescue ActiveRecord::RecordInvalid, ArgumentError => error
      { product: nil, errors: [ error.message ] }
    end
  end
end
