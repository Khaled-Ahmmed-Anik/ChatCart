class ConversationQuestionState
  def initialize(conversation)
    @conversation = conversation
  end

  def self.checkout_contract(order)
    field, answer = Constants::Conversation::QUESTION_FIELDS[order.status]
    return {} unless field

    { "kind" => field, "field" => field, "expected_answer" => answer,
      "pending_order_id" => order.id, "product_id" => order.product_id,
      "variant_id" => order.product_variant_id }.compact
  end

  def discovery_kind
    preferences = conversation.conversation_state.to_h["shopping_preferences"].to_h
    return "discovery_use" unless preferences["device"].present? || preferences["use_case"].present?

    offered_products.one? ? "product_acceptance" : "product"
  end

  def contract(order:, outcome:)
    return {} if order.status.in?(%w[confirmed submitted_to_woocommerce cancelled]) || conversation.handed_over?
    return {} if conversation.conversation_state.to_h["order_context_paused"]

    result = self.class.checkout_contract(order)
    if order.collecting_product?
      kind = if outcome.to_sym == :product_recommendation_requested &&
          Array(conversation.conversation_state.dig("shopping_preferences", "categories")).any?
        discovery_kind
      elsif outcome.to_sym.in?([ :greeting, :product_list_requested, :offered_reference_clarification, :restarted ])
        "product"
      else
        "product_information"
      end
      result.merge!("kind" => kind, "field" => kind, "expected_answer" => kind == "product_acceptance" ? "acknowledgement" : "product_reference",
        "offered_product_ids" => offered_products.map(&:id))
    end
    result
  end

  def record!(message:, order:, contract:)
    state = conversation.conversation_state.to_h
    previous = state["active_question"].to_h
    history = Array(state["question_history"])
    if previous.present?
      answered = previous["pending_order_id"] == order.id && previous["field"] != contract["field"] &&
        order.product_id.present? && contract.present?
      history << previous.merge("status" => answered ? "answered" : "superseded", "closed_by_message_id" => message.id)
    end
    current = contract.merge("status" => contract.present? ? "open" : "closed", "bot_message_id" => message.id)
    conversation.update!(conversation_state: state.merge("active_question" => current,
      "question_history" => history.last(Constants::Conversation::QUESTION_HISTORY_LIMIT)))
  end

  def purchase_offer?(message:, order:)
    state = conversation.conversation_state.to_h
    return nil unless state.key?("active_question")

    question = state["active_question"].to_h
    latest_bot_id = conversation.messages.bot.where("id < ?", message.id).order(id: :desc).pick(:id)
    question["status"] == "open" && question["kind"] == "product_acceptance" &&
      question["pending_order_id"] == order.id && question["bot_message_id"] == latest_bot_id &&
      question["offered_product_ids"] == offered_products.map(&:id) && offered_products.one?
  end

  private

  attr_reader :conversation

  def offered_products
    @offered_products ||= CatalogueConversationReference.new(conversation: conversation, text: "").offered_products
  end
end
