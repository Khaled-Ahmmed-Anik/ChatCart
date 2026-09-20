module Types
  class MutationType < BaseObject
    field :save_product, mutation: Mutations::SaveProduct
    field :archive_product, mutation: Mutations::ArchiveProduct
    field :preview_product_import, mutation: Mutations::PreviewProductImport
    field :approve_product_import, mutation: Mutations::ApproveProductImport
  end
end
