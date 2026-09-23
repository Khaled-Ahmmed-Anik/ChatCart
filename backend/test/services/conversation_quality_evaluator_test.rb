require "test_helper"

class ConversationQualityEvaluatorTest < ActiveSupport::TestCase
  test "flags repeated replies clarification loops frustration and unresolved handover" do
    conversation = Conversation.create!(channel: "facebook", external_customer_id: SecureRandom.uuid, status: :handed_over)
    2.times do
      conversation.messages.create!(
        sender_type: :customer,
        content: "This is frustrating",
        metadata: { "conversation_intelligence" => {
          "needs_clarification" => true, "outcome" => "clarification_needed", "sentiment" => "negative"
        } }
      )
      conversation.messages.create!(sender_type: :bot, content: "Which product do you mean?")
    end

    result = ConversationQualityEvaluator.new(conversation: conversation).call

    assert_operator result[:score], :<, 60
    assert_equal "poor", result[:grade]
    assert_includes result[:flags], "repeated_bot_reply"
    assert_includes result[:flags], "clarification_loop"
    assert_includes result[:flags], "customer_frustration"
    assert_includes result[:flags], "waiting_for_seller"
  end

  test "reports stored review feedback and engine versions" do
    conversation = Conversation.create!(channel: "facebook", external_customer_id: SecureRandom.uuid)
    conversation.update!(conversation_state: {
      "quality_review" => { "label" => "successful" },
      "customer_feedback" => { "rating" => "helpful" }
    })
    conversation.messages.create!(
      sender_type: :bot, content: "Hello", metadata: { "conversation_engine_version" => "2026.09.1" }
    )

    result = ConversationQualityEvaluator.new(conversation: conversation).call

    assert_equal "successful", result.dig(:review, "label")
    assert_equal "helpful", result.dig(:customer_feedback, "rating")
    assert_equal [ "2026.09.1" ], result[:engine_versions]
  end

  test "supports legacy single handover summaries" do
    conversation = Conversation.create!(channel: "facebook", external_customer_id: SecureRandom.uuid)
    conversation.update!(conversation_state: {
      "handover_summary" => { "reason" => "seller_takeover", "created_at" => Time.current.iso8601 }
    })

    result = ConversationQualityEvaluator.new(conversation: conversation).call

    assert_equal 1, result.dig(:metrics, :handovers)
  end
end
