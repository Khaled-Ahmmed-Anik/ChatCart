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
    return unless reference_choice || acknowledgement || text.match?(Constants::Catalogue::CATEGORY_PURCHASE_SUFFIX)
    return unless order.pending_order_items.empty?
    return if acknowledgement && !purchase_question?

    offered = CatalogueConversationReference.new(conversation: order.conversation, text: message.content).offered_products
    return if offered.empty?

    candidates = if reference_choice
      order.product ? offered.select { |product| product.id == order.product_id } : offered
    elsif acknowledgement
      offered
    else
      categories = CatalogueCategoryResolver.call(business: order.conversation.business, text: text)
      return unless categories.any? { |category| category_choice?(text, category) }
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
