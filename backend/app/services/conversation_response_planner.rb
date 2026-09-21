class ConversationResponsePlanner
  Plan = Data.define(:content, :language, :tone, :address_preference, :pending_question, :interrupted)

  def initialize(conversation:, pending_order:, customer_message:, outcome:, interpretation: nil, secondary_outcomes: [])
    @conversation = conversation
    @pending_order = pending_order
    @customer_message = customer_message
    @outcome = outcome.to_sym
    @interpretation = interpretation
    @secondary_outcomes = secondary_outcomes.map(&:to_sym)
  end

  def plan
    content = planned_content
    state = next_state
    conversation.update!(conversation_state: state)

    Plan.new(
      content: content,
      language: state.fetch("preferred_language", "english"),
      tone: state.fetch("preferred_tone", "friendly"),
      address_preference: state["address_preference"],
      pending_question: state["pending_question"],
      interrupted: interruption?
    )
  end

  private

  attr_reader :conversation, :pending_order, :customer_message, :outcome, :interpretation, :secondary_outcomes

  def planned_content
    return focused_clarification if outcome == :clarification_needed

    content = combined_reply
    return content unless interruption?
    return content if pending_prompt.blank? || content.include?(pending_prompt)

    "#{content}\n\nTo continue your order: #{pending_prompt}"
  end

  def base_reply
    BotReplyGenerator.new(
      pending_order: pending_order,
      customer_message: customer_message,
      outcome: outcome,
      interpretation: interpretation,
      address_preference: address_preference
    ).content
  end

  def combined_reply
    return base_reply if outcome.in?(Constants::Conversation::FOCUSED_OUTCOMES)

    replies = [ base_reply ] + secondary_outcomes.map do |secondary_outcome|
      BotReplyGenerator.new(
        pending_order: pending_order,
        customer_message: customer_message,
        outcome: secondary_outcome,
        interpretation: interpretation,
        address_preference: address_preference
      ).content
    end
    replies.compact.map(&:strip).reject(&:blank?).uniq.join("\n\n")
  end

  def focused_clarification
    intents = Array(interpretation&.possible_intents)
    return "Do you want to change your current order, or start a new order?" if intents.intersect?(%w[change_confirmed_order new_order repeat_order])
    return "Which product do you mean? #{product_options}" if intents.intersect?(%w[select_product product_details product_price product_availability])
    return "Would you like to confirm the order now, change something, or leave it for later?" if pending_order.awaiting_confirmation?

    base_reply
  end

  def interruption?
    ([ outcome ] + secondary_outcomes).intersect?(Constants::Conversation::INTERRUPTING_OUTCOMES) && pending_order.status.in?(%w[
      collecting_quantity collecting_name collecting_phone collecting_address awaiting_confirmation
    ])
  end

  def pending_prompt
    BotReplyGenerator.new(pending_order: pending_order).content
  end

  def product_options
    names = conversation.business.products.active.in_stock.order(:name).pluck(:name).to_sentence
    names.present? ? "Available products: #{names}." : "No products are currently available."
  end

  def next_state
    previous_state = conversation.conversation_state.to_h
    previous_state.merge(
      "preferred_language" => preferred_language(previous_state),
      "preferred_tone" => preferred_tone,
      "address_preference" => address_preference,
      "pending_question" => pending_question,
      "last_intent" => interpretation&.intent,
      "last_outcome" => outcome.to_s,
      "last_sentiment" => interpretation&.sentiment,
      "last_customer_message_id" => customer_message.id,
      "interrupted" => interruption?
    ).compact
  end

  def preferred_language(previous_state)
    detected_language = interpretation&.language
    return detected_language if detected_language.in?(%w[english banglish bengali]) && interpretation.confidence >= 0.7

    previous_state.fetch("preferred_language", "english")
  end

  def preferred_tone
    interpretation&.sentiment == "negative" ? "calm_and_helpful" : "friendly"
  end

  def address_preference
    @address_preference ||= ConversationAddressPreference.detect(customer_message.content) ||
      conversation.conversation_state.to_h["address_preference"]
  end

  def pending_question
    {
      "collecting_product" => "product",
      "collecting_quantity" => "quantity",
      "collecting_name" => "customer_name",
      "collecting_phone" => "phone",
      "collecting_address" => "address",
      "awaiting_confirmation" => "confirmation"
    }[pending_order.status]
  end
end
