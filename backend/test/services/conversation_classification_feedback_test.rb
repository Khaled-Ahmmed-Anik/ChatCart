require "test_helper"

class ConversationClassificationFeedbackTest < ActiveSupport::TestCase
  test "records safe classifier telemetry without copying message content" do
    conversation = Conversation.create!(channel: "facebook", external_customer_id: SecureRandom.uuid)
    previous = conversation.messages.create!(sender_type: :customer, content: "not sure", metadata: {
      "conversation_intelligence" => { "outcome" => "clarification_needed" },
      "classification_feedback" => { "predicted_intent" => "product_search" }
    })
    message = conversation.messages.create!(sender_type: :customer, content: "show blue shirts")
    local = CompactIntentClassifier::Result.new(
      interpretation: nil, score: 0.41, runner_up_score: 0.39, source: "local",
      candidate_intent: "list_products", runner_up_intent: "product_search"
    )
    interpretation = AiIntentClassifier::Result.new(
      intent: "product_search", secondary_intents: [], confidence: 0.91, entities: {}, language: "english",
      sentiment: "neutral", needs_clarification: false, possible_intents: []
    )

    feedback = ConversationClassificationFeedback.new(message: message)
    feedback.record_prediction!(classifier: "gemini", interpretation: interpretation, local_result: local)
    feedback.record_outcome!(:product_list_requested)

    stored = message.reload.metadata.fetch("classification_feedback")
    assert_equal "gemini", stored.fetch("classifier")
    assert_equal "product_search", stored.fetch("predicted_intent")
    assert_equal "list_products", stored.fetch("local_candidate_intent")
    assert stored.fetch("classifier_disagreement")
    assert stored.fetch("follows_repair")
    assert_equal previous.id, stored.fetch("previous_customer_message_id")
    assert_not_includes stored.values, message.content
  end

  test "records a reviewed correction against the classified message" do
    conversation = Conversation.create!(channel: "facebook", external_customer_id: SecureRandom.uuid)
    message = conversation.messages.create!(sender_type: :customer, content: "show options", metadata: {
      "classification_feedback" => { "predicted_intent" => "list_products" }
    })

    ConversationClassificationFeedback.new(message: message).record_correction!(
      corrected_intent: "product_search", reviewer_id: 42
    )

    stored = message.reload.metadata.fetch("classification_feedback")
    assert_equal "product_search", stored.fetch("corrected_intent")
    assert_equal false, stored.fetch("was_correct")
    assert_equal 42, stored.fetch("reviewer_id")
    assert stored.fetch("corrected_at").present?
  end
end
