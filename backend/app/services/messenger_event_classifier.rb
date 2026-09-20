class MessengerEventClassifier
  def initialize(event)
    @event = event
  end

  def type
    return :message_echo if message[:is_echo] == true
    return :delivery if event[:delivery].present?
    return :read if event[:read].present?
    return :postback if event[:postback].present?
    return :attachment if message[:attachments].present?
    return :customer_text if event.dig(:sender, :id).present? && message[:text].present?
    return :malformed_message if event.key?(:message)

    :unknown
  end

  private

  attr_reader :event

  def message
    event[:message] || {}
  end
end
