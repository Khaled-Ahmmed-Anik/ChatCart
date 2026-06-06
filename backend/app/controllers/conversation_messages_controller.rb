class ConversationMessagesController < ApplicationController
  def create
    result = CustomerMessageRecorder.new(
      channel: message_params[:channel],
      external_customer_id: message_params[:external_customer_id],
      content: message_params[:content]
    ).record

    render json: {
      conversation: serialize_conversation(result.conversation),
      message: serialize_message(result.message),
      bot_reply: serialize_message(result.bot_reply),
      pending_order: serialize_pending_order(result.pending_order)
    }, status: :created
  rescue ActiveRecord::RecordInvalid => error
    render json: { errors: error.record.errors.to_hash(true) }, status: :unprocessable_entity
  end

  private

  def message_params
    params.expect(conversation_message: [:channel, :external_customer_id, :content])
  end

  def serialize_conversation(conversation)
    {
      id: conversation.id,
      channel: conversation.channel,
      external_customer_id: conversation.external_customer_id,
      status: conversation.status,
      last_message_at: conversation.last_message_at&.iso8601
    }
  end

  def serialize_message(message)
    {
      id: message.id,
      sender_type: message.sender_type,
      content: message.content,
      created_at: message.created_at.iso8601
    }
  end

  def serialize_pending_order(pending_order)
    {
      id: pending_order.id,
      status: pending_order.status,
      product_id: pending_order.product_id,
      quantity: pending_order.quantity,
      customer_name: pending_order.customer_name,
      phone: pending_order.phone,
      address: pending_order.address,
      total_price: pending_order.total_price.to_s,
      ready_for_confirmation: pending_order.ready_for_confirmation?
    }
  end
end
