require "test_helper"

class ConversationEscalationPolicyTest < ActiveSupport::TestCase
  test "hands over consecutive unresolved requests but resets on a successful answer" do
    conversation = Conversation.create!(channel: "facebook", external_customer_id: SecureRandom.uuid)
    3.times do
      conversation.messages.create!(sender_type: :customer, content: "unresolved question", metadata: {
        "conversation_intelligence" => { "outcome" => "product_not_found" }
      })
    end
    policy = ConversationEscalationPolicy.new(conversation: conversation, interpretation: nil, outcome: :product_not_found)
    assert policy.handover?
    assert_equal "repeated_unresolved_request", policy.reason
    conversation.messages.create!(sender_type: :customer, content: "price?", metadata: {
      "conversation_intelligence" => { "outcome" => "price_inquiry" }
    })
    assert_not policy.handover?
  end

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

  test "does not escalate non-consecutive clarification failures" do
    conversation = Conversation.create!(channel: "facebook", external_customer_id: SecureRandom.uuid)
    [ true, true, false, true ].each do |needs_clarification|
      conversation.messages.create!(sender_type: :customer, content: "message", metadata: {
        "conversation_intelligence" => {
          "intent" => needs_clarification ? "unclear" : "product_details",
          "needs_clarification" => needs_clarification
        }
      })
    end

    policy = ConversationEscalationPolicy.new(
      conversation: conversation, interpretation: nil, outcome: :clarification_needed
    )

    assert_not policy.handover?
  end

  test "immediately escalates a refund request" do
    conversation = Conversation.create!(channel: "facebook", external_customer_id: SecureRandom.uuid)
    conversation.messages.create!(sender_type: :customer, content: "I need a refund")
    interpretation = AiIntentClassifier::Result.new(
      intent: "refund_request", secondary_intents: [], confidence: 0.95,
      entities: {}.with_indifferent_access, language: "english", sentiment: "negative",
      needs_clarification: false, possible_intents: []
    )

    policy = ConversationEscalationPolicy.new(
      conversation: conversation, interpretation: interpretation, outcome: :refund_requested
    )

    assert policy.handover?
    assert_equal "refund_or_replacement", policy.reason
  end

  test "immediately escalates a delivered but not received dispute" do
    conversation = Conversation.create!(channel: "facebook", external_customer_id: SecureRandom.uuid)
    conversation.messages.create!(sender_type: :customer, content: "Parcel says delivered but I did not receive it")

    policy = ConversationEscalationPolicy.new(
      conversation: conversation, interpretation: nil, outcome: :no_change
    )

    assert policy.handover?
    assert_equal "delivery_dispute", policy.reason
  end
end
