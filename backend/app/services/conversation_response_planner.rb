class ConversationResponsePlanner
  INTERRUPTING_OUTCOMES = %i[
    price_inquiry stock_inquiry product_details_requested product_recommendation_requested
    product_comparison_requested product_variants_requested product_images_requested
    payment_methods_requested cash_on_delivery_requested delivery_charge_requested
    delivery_area_requested delivery_time_requested
  ].freeze

  Plan = Data.define(:content, :language, :tone, :pending_question, :interrupted)

  def initialize(conversation:, pending_order:, customer_message:, outcome:, interpretation: nil)
    @conversation = conversation
    @pending_order = pending_order
    @customer_message = customer_message
    @outcome = outcome.to_sym
    @interpretation = interpretation
  end

  def plan
    content = planned_content
    state = next_state
    conversation.update!(conversation_state: state)

    Plan.new(
      content: content,
      language: state.fetch("preferred_language", "english"),
      tone: state.fetch("preferred_tone", "friendly"),
      pending_question: state["pending_question"],
      interrupted: interruption?
    )
  end

  private

  attr_reader :conversation, :pending_order, :customer_message, :outcome, :interpretation

  def planned_content
    return focused_clarification if outcome == :clarification_needed

    content = base_reply
    return content unless interruption?
    return content if pending_prompt.blank? || content.include?(pending_prompt)

    "#{content}\n\nTo continue your order: #{pending_prompt}"
  end

  def base_reply
    BotReplyGenerator.new(
      pending_order: pending_order,
      customer_message: customer_message,
      outcome: outcome,
      interpretation: interpretation
    ).content
  end

  def focused_clarification
    intents = Array(interpretation&.possible_intents)
    return "Do you want to change your current order, or start a new order?" if intents.intersect?(%w[change_confirmed_order new_order repeat_order])
    return "Which product do you mean? #{product_options}" if intents.intersect?(%w[select_product product_details product_price product_availability])
    return "Would you like to confirm the order now, change something, or leave it for later?" if pending_order.awaiting_confirmation?

    base_reply
  end

  def interruption?
    outcome.in?(INTERRUPTING_OUTCOMES) && pending_order.status.in?(%w[
      collecting_quantity collecting_name collecting_phone collecting_address awaiting_confirmation
    ])
  end

  def pending_prompt
    BotReplyGenerator.new(pending_order: pending_order).content
  end

  def product_options
    names = Product.active.in_stock.order(:name).pluck(:name).to_sentence
    names.present? ? "Available products: #{names}." : "No products are currently available."
  end

  def next_state
    previous_state = conversation.conversation_state.to_h
    previous_state.merge(
      "preferred_language" => preferred_language(previous_state),
      "preferred_tone" => preferred_tone,
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
