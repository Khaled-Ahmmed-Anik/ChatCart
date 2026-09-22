require "test_helper"

class ConversationEscalationPolicyTest < ActiveSupport::TestCase
  test "escalates after repeated low-confidence misunderstandings" do
    conversation = Conversation.create!(channel: "facebook", external_customer_id: SecureRandom.uuid)
    3.times do
      conversation.messages.create!(
        sender_type: :customer,
        content: "oi ta",
        metadata: { "conversation_intelligence" => { "intent" => "unclear", "needs_clarification" => true } }
      )
    end

    policy = ConversationEscalationPolicy.new(
      conversation: conversation, interpretation: nil, outcome: :clarification_needed
    )

    assert policy.handover?
    assert_equal "repeated_confusion", policy.reason
  end

  test "gives the customer a second recovery attempt before escalating" do
    conversation = Conversation.create!(channel: "facebook", external_customer_id: SecureRandom.uuid)
    2.times do
      conversation.messages.create!(sender_type: :customer, content: "oi ta", metadata: {
        "conversation_intelligence" => { "intent" => "unclear", "needs_clarification" => true }
      })
    end

    policy = ConversationEscalationPolicy.new(conversation: conversation, interpretation: nil,
      outcome: :clarification_needed)

    assert_not policy.handover?
  end
end
