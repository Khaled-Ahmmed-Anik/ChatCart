class CataloguePurchaseAcceptance
  Result = Data.define(:product, :candidates)

  def initialize(message:, pending_order:)
    @message = message
    @order = pending_order
  end

  def call
    return unless order&.status.in?(%w[collecting_product collecting_quantity collecting_variant]) && order.conversation

    text = ConversationTextNormalizer.call(message.content)
    reference_choice = text.match?(Constants::Catalogue::PURCHASE_REFERENCE_ACCEPTANCE)
    acknowledgement = text.match?(Constants::Catalogue::PURCHASE_ACKNOWLEDGEMENT)
    previous_category = text.match(Constants::Catalogue::PREVIOUS_CATEGORY_ACCEPTANCE)
    quantity = ConversationQuantityParser.call(text)
    quantity_acceptance = quantity.present? && text.match?(Constants::Catalogue::OFFER_QUANTITY_ACCEPTANCE) && purchase_question?
    return unless reference_choice || acknowledgement || previous_category || quantity_acceptance || text.match?(Constants::Catalogue::CATEGORY_PURCHASE_SUFFIX)
    return unless order.pending_order_items.empty?
    return if acknowledgement && !purchase_question?

    offered = CatalogueConversationReference.new(conversation: order.conversation, text: message.content).offered_products
    return if offered.empty?

    candidates = if reference_choice
      order.product ? offered.select { |product| product.id == order.product_id } : offered
    elsif acknowledgement || quantity_acceptance
      offered
    else
      category_text = previous_category ? previous_category[1] : text
      categories = CatalogueCategoryResolver.call(business: order.conversation.business, text: category_text)
      return unless previous_category || categories.any? { |category| category_choice?(text, category) }
      offered.select { |product| categories.include?(product.category) }
    end
    return if candidates.empty?
    return if candidates.one? && !candidates.first.total_available_stock.positive?
    return if order.product_id && candidates.none? { |product| product.id == order.product_id }

    Result.new(product: candidates.one? ? candidates.first : nil, candidates: candidates)
  end

  private

  attr_reader :message, :order

  def category_choice?(text, category)
    labels = [ ConversationTextNormalizer.call(category), CatalogueCategoryResolver.normalize(category) ].uniq.map { |label| Regexp.escape(label) }.join("|")
    text.match?(/\A(?:#{labels})\s+(?:ta|ti)(?:\s+(?:nibo|nite chai|please))?\z/)
  end

  def purchase_question?
    typed = ConversationQuestionState.new(order.conversation).purchase_offer?(message: message, order: order)
    return typed unless typed.nil?

    previous = order.conversation.messages.bot.where("id < ?", message.id).order(id: :desc).pick(:content)
    previous.to_s.match?(Constants::Catalogue::PURCHASE_OFFER_QUESTION)
  end
end
