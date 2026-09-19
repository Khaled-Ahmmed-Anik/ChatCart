class MessengerSafeLogger
  def self.info(action, attributes = {})
    Rails.logger.info({ component: "messenger", action: action, **attributes.compact }.to_json)
  end

  def self.error(action, attributes = {})
    Rails.logger.error({ component: "messenger", action: action, **attributes.compact }.to_json)
  end
end
