module Types
  class QueryType < BaseObject
    field :viewer, UserType, null: false
    field :current_business, BusinessType, null: false
    field :analytics, AnalyticsType, null: false
    field :products, [ ProductType ], null: false do
      argument :first, Integer, required: false, default_value: 50,
        validates: { numericality: { greater_than: 0, less_than_or_equal_to: 100 } }
    end

    def viewer
      context[:current_user]
    end

    def current_business
      context[:current_business]
    end

    def analytics
      AnalyticsSnapshot.new(business: context[:current_business]).call
    end

    def products(first:)
      context[:current_business].products.order(:name).limit(first)
    end
  end
end
