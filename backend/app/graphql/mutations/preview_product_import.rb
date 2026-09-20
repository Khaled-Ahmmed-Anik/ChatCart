module Mutations
  class PreviewProductImport < BaseMutation
    argument :url, String, required: true

    field :draft, Types::ProductImportDraftType
    field :errors, [ String ], null: false

    def resolve(url:)
      require_management_role!
      draft = ProductImportPreview.new(business: context[:current_business], source_url: url).create!
      { draft: draft, errors: draft.status == "failed" ? [ draft.error ] : [] }
    end
  end
end
