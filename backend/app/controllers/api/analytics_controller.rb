module Api
  class AnalyticsController < BaseController
    def show
      conversations = current_business.conversations
      orders = current_business.orders
      customers = conversations.distinct.count(:external_customer_id)
      ordering_customers = orders.joins(:conversation).distinct.count("conversations.external_customer_id")
      repeat_customers = orders.joins(:conversation).group("conversations.external_customer_id").having("COUNT(orders.id) > 1").count.length

      render json: {
        conversations: conversations.count,
        unique_customers: customers,
        confirmed_orders: orders.count,
        conversation_to_order_rate: percentage(orders.select(:conversation_id).distinct.count, conversations.count),
        ordering_customers: ordering_customers,
        repeat_customers: repeat_customers,
        repeat_customer_rate: percentage(repeat_customers, ordering_customers),
        revenue: orders.where.not(status: "cancelled").sum(:total).to_s,
        average_order_value: orders.where.not(status: "cancelled").average(:total).to_d.to_s,
        orders_by_channel: orders.joins(:conversation).group("conversations.channel").count,
        orders_by_status: orders.group(:status).count,
        top_products: top_products
      }
    end

    private

    def percentage(numerator, denominator)
      return 0.0 if denominator.zero?

      ((numerator.to_f / denominator) * 100).round(2)
    end

    def top_products
      OrderItem.joins(:order).where(orders: { business_id: current_business.id })
        .group(:product_name).order(Arel.sql("SUM(quantity) DESC")).limit(10).sum(:quantity)
    end
  end
end
