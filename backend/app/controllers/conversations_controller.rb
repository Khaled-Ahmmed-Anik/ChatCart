class ConversationsController < ApplicationController
  def lookup
    return render_missing_lookup_params if lookup_params_missing?

    conversation = requested_business.conversations
      .includes(:messages, pending_orders: :product)
      .find_by(channel: params[:channel], external_customer_id: params[:external_customer_id])

    if conversation.present?
      render json: serialize_conversation(conversation)
    else
      render json: { error: "Conversation not found" }, status: :not_found
    end
  end

  private

  def lookup_params_missing?
    params[:channel].blank? || params[:external_customer_id].blank?
  end

  def render_missing_lookup_params
    render json: {
      errors: {
        channel: [ "can't be blank" ],
        external_customer_id: [ "can't be blank" ]
      }
    }, status: :unprocessable_entity
  end

  def serialize_conversation(conversation)
    {
      id: conversation.id,
      channel: conversation.channel,
      external_customer_id: conversation.external_customer_id,
      status: conversation.status,
      last_message_at: conversation.last_message_at&.iso8601,
      conversation_state: conversation.conversation_state,
      messages: conversation.messages.order(:created_at, :id).map { |message| serialize_message(message) },
      pending_order: serialize_pending_order(conversation.pending_order)
    }
  end

  def serialize_message(message)
    {
      id: message.id,
      sender_type: message.sender_type,
      content: message.content,
      metadata: message.metadata,
      created_at: message.created_at.iso8601
    }
  end

  def serialize_pending_order(pending_order)
    return nil if pending_order.blank?

    {
      id: pending_order.id,
      status: pending_order.status,
      product: serialize_product(pending_order.product),
      quantity: pending_order.quantity,
      customer_name: pending_order.customer_name,
      phone: pending_order.phone,
      address: pending_order.address,
      woo_commerce_order_id: pending_order.woo_commerce_order_id,
      change_history: pending_order.change_history,
      total_price: pending_order.total_price.to_s,
      ready_for_confirmation: pending_order.ready_for_confirmation?
    }
  end

  def serialize_product(product)
    return nil if product.blank?

    {
      id: product.id,
      name: product.name,
      woo_commerce_product_id: product.woo_commerce_product_id,
      price: product.price.to_s,
      stock_quantity: product.stock_quantity,
      tags: product.tags,
      active: product.active
    }
  end
end
