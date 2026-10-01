require "test_helper"

class ConversationAiRolloutTest < ActiveSupport::TestCase
  test "defaults to naturalization enabled and tool planning disabled" do
    conversation = Conversation.create!(channel: "facebook", external_customer_id: SecureRandom.uuid)

    assert ConversationAiRollout.enabled?(:naturalizer, conversation: conversation, environment: {})
    assert_not ConversationAiRollout.enabled?(:planner, conversation: conversation, environment: {})
  end

  test "supports deterministic percentage rollout" do
    conversation = Conversation.create!(channel: "facebook", external_customer_id: SecureRandom.uuid)
    environment = {
      "CONVERSATION_PLANNER_ENABLED" => "true",
      "CONVERSATION_PLANNER_ROLLOUT_PERCENT" => "40"
    }

    first = ConversationAiRollout.enabled?(:planner, conversation: conversation, environment: environment)
    second = ConversationAiRollout.enabled?(:planner, conversation: conversation, environment: environment)

    assert_equal first, second
  end

  test "honors disabled and boundary percentages" do
    conversation = Conversation.create!(channel: "facebook", external_customer_id: SecureRandom.uuid)

    assert_not ConversationAiRollout.enabled?(:planner, conversation: conversation, environment: {
      "CONVERSATION_PLANNER_ENABLED" => "false", "CONVERSATION_PLANNER_ROLLOUT_PERCENT" => "100"
    })
    assert_not ConversationAiRollout.enabled?(:planner, conversation: conversation, environment: {
      "CONVERSATION_PLANNER_ENABLED" => "true", "CONVERSATION_PLANNER_ROLLOUT_PERCENT" => "0"
    })
    assert ConversationAiRollout.enabled?(:planner, conversation: conversation, environment: {
      "CONVERSATION_PLANNER_ENABLED" => "true", "CONVERSATION_PLANNER_ROLLOUT_PERCENT" => "100"
    })
  end
end
