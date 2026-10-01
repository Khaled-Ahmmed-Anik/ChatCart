require "zlib"

class ConversationAiRollout
  FEATURES = {
    planner: { flag: "CONVERSATION_PLANNER_ENABLED", percentage: "CONVERSATION_PLANNER_ROLLOUT_PERCENT", default: false },
    naturalizer: { flag: "CONVERSATION_NATURALIZER_ENABLED", percentage: "CONVERSATION_NATURALIZER_ROLLOUT_PERCENT", default: true },
    naturalizer_all_turns: {
      flag: "CONVERSATION_NATURALIZER_ALL_TURNS_ENABLED",
      percentage: "CONVERSATION_NATURALIZER_ALL_TURNS_ROLLOUT_PERCENT",
      default: false
    }
  }.freeze

  def self.enabled?(feature, conversation:, environment: ENV)
    config = FEATURES.fetch(feature.to_sym)
    enabled = ActiveModel::Type::Boolean.new.cast(environment.fetch(config.fetch(:flag), config.fetch(:default)))
    return false unless enabled

    percentage = environment.fetch(config.fetch(:percentage), 100).to_i.clamp(0, 100)
    return true if percentage == 100
    return false if percentage.zero?

    Zlib.crc32("#{feature}:#{conversation.id}") % 100 < percentage
  end
end
