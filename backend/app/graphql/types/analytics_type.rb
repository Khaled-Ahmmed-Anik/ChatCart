module Types
  class AnalyticsType < BaseObject
    field :conversations, Integer, null: false
    field :unique_customers, Integer, null: false
    field :confirmed_orders, Integer, null: false
    field :conversation_to_order_rate, Float, null: false
    field :ordering_customers, Integer, null: false
    field :repeat_customers, Integer, null: false
    field :repeat_customer_rate, Float, null: false
    field :revenue, String, null: false
    field :average_order_value, String, null: false
    field :orders_by_channel, GraphQL::Types::JSON, null: false
    field :orders_by_status, GraphQL::Types::JSON, null: false
    field :top_products, GraphQL::Types::JSON, null: false
  end
end
