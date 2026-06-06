class ConversationMessagesController < ApplicationController
  def create
    conversation = find_or_create_conversation
    message = nil
    bot_reply = nil
    pending_order = nil

    Conversation.transaction do
      conversation.update!(last_message_at: Time.current)
      message = conversation.messages.create!(sender_type: :customer, content: message_params[:content])
      pending_order = conversation.pending_order || conversation.create_pending_order!
      ConversationMessageProcessor.new(message: message, pending_order: pending_order).process
      bot_reply = conversation.messages.create!(
        sender_type: :bot,
        content: BotReplyGenerator.new(pending_order: pending_order).content
      )
    end

    render json: {
      conversation: serialize_conversation(conversation),
      message: serialize_message(message),
      bot_reply: serialize_message(bot_reply),
      pending_order: serialize_pending_order(pending_order)
    }, status: :created
  rescue ActiveRecord::RecordInvalid => error
    render json: { errors: error.record.errors.to_hash(true) }, status: :unprocessable_entity
  end

  private

  def find_or_create_conversation
    Conversation.find_or_create_by!(
      channel: message_params[:channel],
      external_customer_id: message_params[:external_customer_id]
    )
  end

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
