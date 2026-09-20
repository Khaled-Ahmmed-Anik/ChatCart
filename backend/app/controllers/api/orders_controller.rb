module Api
  class OrdersController < BaseController
    before_action -> { require_roles!(:owner, :admin, :sales_agent, :fulfilment_agent) }, only: %i[update submit_delivery]
    before_action :set_order, only: %i[show update submit_delivery]

    def index
      orders = filtered_orders.includes(:order_items).recent_first
      render json: orders.map { |order| serialize(order) }
    end

    def show
      render json: serialize(@order, include_conversation: true)
    end

    def update
      return if performed?

      @order.update!(params.expect(order: [ :status ]))
      render json: serialize(@order)
    rescue ActiveRecord::RecordInvalid => error
      render json: { errors: error.record.errors.to_hash(true) }, status: :unprocessable_entity
    end

    def export
      send_data csv_for(filtered_orders.includes(:order_items).recent_first),
        filename: "orders-#{Date.current}.csv", type: "text/csv"
    end

    def submit_delivery
      return if performed?

      integration = current_business.delivery_integration
      return render json: { error: "No active delivery integration" }, status: :unprocessable_entity unless integration&.active?

      submission = @order.delivery_submissions.find_or_create_by!(delivery_integration: integration)
      SubmitDeliveryJob.perform_later(submission)
      render json: submission, status: :accepted
    end

    private

    def set_order
      @order = current_business.orders.find(params[:id])
    end

    def filtered_orders
      scope = current_business.orders
      scope = scope.where(status: params[:status]) if params[:status].present?
      scope = scope.where("confirmed_at >= ?", Time.zone.parse(params[:from])) if params[:from].present?
      scope = scope.where("confirmed_at <= ?", Time.zone.parse(params[:to]).end_of_day) if params[:to].present?
      scope
    end

    def serialize(order, include_conversation: false)
      data = order.as_json(except: %i[created_at updated_at]).merge(
        channel: order.conversation.channel,
        items: order.order_items.as_json(only: %i[product_id product_name quantity unit_price total])
      )
      if include_conversation
        data[:conversation] = {
          id: order.conversation_id,
          channel: order.conversation.channel,
          external_customer_id: order.conversation.external_customer_id,
          messages: order.conversation.messages.order(:created_at, :id).as_json(
            only: %i[id sender_type content metadata created_at]
          )
        }
      end
      data
    end

    def csv_for(orders)
      rows = [ %w[number status confirmed_at customer_name phone address channel products subtotal delivery_charge total currency] ]
      orders.each do |order|
        products = order.order_items.map { |item| "#{item.quantity} x #{item.product_name}" }.join("; ")
        rows << [ order.number, order.status, order.confirmed_at.iso8601, order.customer_name, order.phone,
          order.address, order.conversation.channel, products, order.subtotal, order.delivery_charge,
          order.total, order.currency ]
      end
      rows.map { |row| row.map { |value| csv_cell(value) }.join(",") }.join("\n") + "\n"
    end

    def csv_cell(value)
      %Q("#{value.to_s.gsub('"', '""')}")
    end
  end
end
