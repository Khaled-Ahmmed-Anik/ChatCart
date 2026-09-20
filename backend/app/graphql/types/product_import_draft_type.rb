module Types
  class ProductImportDraftType < BaseObject
    field :id, ID, null: false
    field :source_url, String, null: false
    field :status, String, null: false
    field :extracted_data, GraphQL::Types::JSON, null: false
    field :error, String
    field :product, ProductType
  end
end
