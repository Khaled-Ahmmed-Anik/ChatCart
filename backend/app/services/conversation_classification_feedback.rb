class ConversationClassificationFeedback
  REPAIR_OUTCOMES = %w[
    clarification_needed name_required invalid_phone invalid_quantity product_not_found product_ambiguous
    variant_not_found confirmation_unclear invalid_order_update
  ].freeze

  def initialize(message:)
    @message = message
  end

  def record_prediction!(classifier:, interpretation:, local_result:)
    previous = previous_customer_message
    previous_intelligence = previous&.metadata.to_h.fetch("conversation_intelligence", {}).to_h
    previous_feedback = previous&.metadata.to_h.fetch("classification_feedback", {}).to_h
    predicted_intent = interpretation&.intent

    update_feedback!(
      "classifier" => classifier,
      "predicted_intent" => predicted_intent,
      "confidence" => interpretation&.confidence,
      "local_candidate_intent" => local_result.candidate_intent,
      "local_score" => local_result.score,
      "local_runner_up_intent" => local_result.runner_up_intent,
      "local_runner_up_score" => local_result.runner_up_score,
      "classifier_disagreement" => classifier == "gemini" && predicted_intent.present? &&
        local_result.candidate_intent.present? && local_result.candidate_intent != predicted_intent,
      "previous_customer_message_id" => previous&.id,
      "repeated_intent" => predicted_intent.present? && predicted_intent == previous_feedback["predicted_intent"],
      "follows_repair" => previous_intelligence["outcome"].in?(REPAIR_OUTCOMES)
    )
  end

  def record_outcome!(outcome)
    update_feedback!(
      "outcome" => outcome.to_s,
      "required_repair" => outcome.to_s.in?(REPAIR_OUTCOMES)
    )
  end

  def record_correction!(corrected_intent:, reviewer_id:)
    update_feedback!(
      "corrected_intent" => corrected_intent,
      "corrected_at" => Time.current.iso8601,
      "reviewer_id" => reviewer_id,
      "was_correct" => feedback["predicted_intent"] == corrected_intent
    )
  end

  private

  attr_reader :message

  def previous_customer_message
    message.conversation.messages.customer.where("id < ?", message.id).order(id: :desc).first
  end

  def feedback
    message.metadata.to_h.fetch("classification_feedback", {}).to_h
  end

  def update_feedback!(attributes)
    safe_attributes = attributes.compact
    message.update!(metadata: message.metadata.to_h.merge(
      "classification_feedback" => feedback.merge(safe_attributes)
    ))
  end
end
