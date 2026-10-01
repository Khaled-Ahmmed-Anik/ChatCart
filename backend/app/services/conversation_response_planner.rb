class ConversationResponsePlanner
  Plan = Data.define(
    :content, :language, :tone, :address_preference, :pending_question, :interrupted,
    :goal, :actions, :facts, :confidence, :needs_clarification, :handover_required
  ) do
    def to_h
      {
        content: content,
        language: language,
        tone: tone,
        address_preference: address_preference,
        pending_question: pending_question,
        interrupted: interrupted,
        goal: goal,
        actions: actions,
        facts: facts,
        confidence: confidence,
        needs_clarification: needs_clarification,
        handover_required: handover_required
      }.compact
    end
  end

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
      interrupted: interruption?,
      goal: response_goal,
      actions: planned_actions,
      facts: approved_facts,
      confidence: interpretation&.confidence || 1.0,
      needs_clarification: outcome == :clarification_needed || interpretation&.needs_clarification == true,
      handover_required: outcome == :human_handover_started
    )
  end

  private

  attr_reader :conversation, :pending_order, :customer_message, :outcome, :interpretation, :secondary_outcomes

  def planned_content
    return focused_clarification if outcome == :clarification_needed

    content = combined_reply
    return content unless interruption?
    return content if pending_prompt.blank? || content.include?(pending_prompt)

    "#{content}\n\n#{continuation_prompt}"
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
      collecting_variant collecting_quantity collecting_name collecting_phone collecting_address awaiting_confirmation
    ])
  end

  def pending_prompt
    return banglish_pending_prompt if preferred_language(conversation.conversation_state.to_h) == "banglish"

    case pending_order.status
    when "collecting_variant"
      "Which size would you like for #{pending_order.product.name}?"
    when "collecting_quantity"
      "How many #{pending_order.product.name} would you like?"
    when "collecting_name"
      "What name should I put on the order?"
    when "collecting_phone"
      "What phone number should we use?"
    when "collecting_address"
      "What’s the delivery address?"
    when "awaiting_confirmation"
      "Would you like to confirm the order or change something?"
    else
      BotReplyGenerator.new(pending_order: pending_order).content
    end
  end

  def continuation_prompt
    if conversation.conversation_state.to_h["context_switch_count"].to_i.positive? && selected_item.present?
      return "Apnar #{selected_item} selection-ta save ache. Eta niye continue korben, change korben, naki ekhon pause rakhben?" if
        preferred_language(conversation.conversation_state.to_h) == "banglish"

      return "Your order is still saved. Would you like to continue with #{selected_item}, change it, or pause it for now?"
    end

    "To continue your order: #{pending_prompt}"
  end

  def selected_item
    [ pending_order.product&.name, pending_order.product_variant&.display_name ].compact.join(" ").presence
  end

  def banglish_pending_prompt
    case pending_order.status
    when "collecting_variant"
      "#{pending_order.product.name}-er kon size ta niben?"
    when "collecting_quantity"
      "#{pending_order.product.name}-er koyta niben?"
    when "collecting_name"
      "Order-ta kon name-e dibo?"
    when "collecting_phone"
      "Delivery-r jonno phone number-ta diben?"
    when "collecting_address"
      "Delivery address-ta diben?"
    when "awaiting_confirmation"
      "Order-ta confirm korben, naki kichu change korben?"
    end
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
      "interrupted" => interruption?,
      "context_switch_count" => next_context_switch_count(previous_state)
    ).compact
  end

  def next_context_switch_count(previous_state)
    return previous_state["context_switch_count"].to_i + 1 if interruption?
    return 0 if outcome.in?(%i[product_selected variant_selected quantity_collected name_collected phone_collected
      address_collected confirmed cancelled restarted])

    previous_state["context_switch_count"].to_i
  end

  def preferred_language(previous_state)
    detected_language = interpretation&.language
    if customer_message.content.to_s.split.size <= 2 && previous_state["preferred_language"].present? &&
        outcome != :language_preference
      return previous_state["preferred_language"]
    end
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

  def response_goal
    return "handover_to_seller" if outcome == :human_handover_started
    return "clarify_customer_request" if outcome == :clarification_needed
    return "complete_order" if outcome == :confirmed
    return "answer_and_resume_order" if interruption?
    return "collect_#{pending_question}" if pending_question.present?

    "answer_customer"
  end

  def planned_actions
    actions = [ { "type" => outcome.to_s } ]
    secondary_outcomes.each { |secondary| actions << { "type" => secondary.to_s } }
    actions << { "type" => "ask", "field" => pending_question } if pending_question.present?
    actions.uniq
  end

  def approved_facts
    {
      "business_name" => conversation.business.name,
      "product_id" => pending_order.product_id,
      "product_name" => pending_order.product&.name,
      "variant_id" => pending_order.product_variant_id,
      "variant_name" => pending_order.product_variant&.display_name,
      "quantity" => pending_order.quantity,
      "unit_price" => pending_order.product.present? ? pending_order.unit_price.to_s : nil,
      "total_price" => pending_order.product.present? && pending_order.quantity.present? ? pending_order.total_price.to_s : nil,
      "order_status" => pending_order.status
    }.compact
  end
end
