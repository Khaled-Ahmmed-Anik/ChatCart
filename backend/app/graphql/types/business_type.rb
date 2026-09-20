module Types
  class BusinessType < BaseObject
    field :id, ID, null: false
    field :name, String, null: false
    field :slug, String, null: false
    field :category, String
    field :default_language, String, null: false
    field :timezone, String, null: false
    field :currency, String, null: false
    field :status, String, null: false
    field :settings, GraphQL::Types::JSON, null: false
  end
end
