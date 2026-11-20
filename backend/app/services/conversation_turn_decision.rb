class ConversationTurnDecision
  Decision = Data.define(:route, :outcome, :product) do
    def metadata = { "route" => route.to_s, "outcome" => outcome&.to_s, "product_id" => product&.id }.compact
  end

  def initialize(message:, pending_order:)
    @message = message
    @order = pending_order
    @text = message.content.to_s.strip
    @request = ConversationTurnRequest.new(text)
    @reference = CatalogueConversationReference.new(conversation: order.conversation, text: text)
  end

  def call
    if text.match?(Constants::Conversation::EXPLICIT_CANCELLATION) && !order.confirmed? && !order.submitted_to_woocommerce?
      return decision(:cancel, :cancelled)
    end
    return decision(:answer, :confirmation_deferred) if request.browsing_only?
    return decision(:answer, :device_preference_requested) if text.match?(Constants::Catalogue::DEVICE_RECALL)
    return decision(:answer, :product_comparison_requested) if request.comparison? && reference.offered_products.any?
    position = reference.option_position
    if position && reference.offered_products.any? && position >= reference.offered_products.size
      return decision(:answer, :offered_reference_clarification)
    end
    return decision(:answer, :catalogue_quote_requested) if quote?
    if text.match?(/\b(?:not that one|oita na)\b/i) && position && reference.product
      return decision(:answer, :product_details_requested, reference.product)
    end
    if factual?
      outcome = if request.comparison?
        :product_comparison_requested
      elsif request.variants?
        :product_variants_requested
      elsif request.price? && !Constants::Catalogue::QUESTION_TOPICS.values.any? { |topic| text.match?(topic.fetch(:question)) }
        :price_inquiry
      elsif text.match?(/\b(stock|available|availability)\b/i)
        :stock_inquiry
      else
        :product_details_requested
      end
      return decision(:answer, outcome, reference.product)
    end
    acceptance = CataloguePurchaseAcceptance.new(message: message, pending_order: order).call
    return decision(:select, :product_selected, acceptance.product) if acceptance&.product
    return decision(:answer, :offered_reference_clarification) if acceptance

    decision(:commerce, nil)
  end

  private

  attr_reader :message, :order, :text, :request, :reference

  def decision(route, outcome, product = nil) = Decision.new(route: route, outcome: outcome, product: product)

  def quote?
    return false unless text.match?(Constants::Conversation::CART_TOTAL_REQUEST) || request.price?

    quantity = ConversationQuantityParser.call(text, products: order.conversation.business.products.available_for_sale.to_a)
    requested = text.match?(Constants::Conversation::CART_TOTAL_REQUEST) ||
      (request.price? && quantity.to_i > 1 && !text.match?(Constants::Conversation::EXPLICIT_QUANTITY_UNITS))
    requested && order.line_items.empty? && !text.match?(Constants::Conversation::CART_MUTATION_CUE) &&
      CataloguePriceQuote.new(conversation: order.conversation, text: text).content.present?
  end

  def factual?
    request.information_only? && reference.product && !text.match?(/\d+(?:\.\d+)?\s*(?:ml|মিলি)/i) &&
      ConversationActionPlanner.policy_information_outcomes(text).empty? &&
      !text.match?(Constants::Conversation::CART_TOTAL_REQUEST) && !text.match?(Constants::Conversation::CART_CONTENTS_REQUEST)
  end
end
