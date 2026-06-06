class CustomerMessageRecorder
  Result = Struct.new(:conversation, :message, :bot_reply, :pending_order, keyword_init: true)

  def initialize(channel:, external_customer_id:, content:, metadata: {})
    @channel = channel
    @external_customer_id = external_customer_id
    @content = content
    @metadata = metadata
  end

  def record
    conversation = nil
    message = nil
    bot_reply = nil
    pending_order = nil

    Conversation.transaction do
      conversation = find_or_create_conversation
      conversation.update!(last_message_at: Time.current)
      message = conversation.messages.create!(
        sender_type: :customer,
        content: content,
        metadata: metadata
      )
      pending_order = conversation.pending_order || conversation.create_pending_order!
      ConversationMessageProcessor.new(message: message, pending_order: pending_order).process
      bot_reply = conversation.messages.create!(
        sender_type: :bot,
        content: BotReplyGenerator.new(pending_order: pending_order).content
      )
    end

    Result.new(
      conversation: conversation,
      message: message,
      bot_reply: bot_reply,
      pending_order: pending_order
    )
  end

  private

  attr_reader :channel, :external_customer_id, :content, :metadata

  def find_or_create_conversation
    Conversation.find_or_create_by!(
      channel: channel,
      external_customer_id: external_customer_id
    )
  end
end
