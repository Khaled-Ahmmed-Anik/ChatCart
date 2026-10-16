# Captions supply order details only after the customer approves the pictured product.
class ConversationPhotoOrderDetails
  def initialize(product:, caption:)
    @product = product
    @caption = caption.to_s.unicode_normalize(:nfkc).downcase.squish
  end

  def requested?
    caption.match?(Constants::PhotoRecognition::ORDER_REQUEST) &&
      !caption.match?(Constants::PhotoRecognition::ORDER_NEGATION) && !caption.match?(/[?？]/)
  end

  def addition? = requested? && caption.match?(Constants::PhotoRecognition::CART_ADDITION)

  def conflicting_product?
    return false unless requested?

    normalized = ConversationTextNormalizer.call(caption)
    product.business.products.available_for_sale.where.not(id: product.id).any? do |candidate|
      candidate.searchable_names.any? do |name|
        normalized.match?(/(?:\A|\s)#{Regexp.escape(ConversationTextNormalizer.call(name))}(?:\z|\s)/)
      end
    end
  end

  def ambiguous?
    return false unless requested?

    conflicting_product? || caption.tr("০১২৩৪৫৬৭৮৯", "0123456789").match?(Constants::PhotoRecognition::UNSAFE_CAPTION_QUANTITY) ||
      text.scan(/\b(?:#{Constants::Conversation::NUMBER_WORDS.keys.join('|')})\b|\d+\s*(?:pcs?|pieces?|bottles?|units?)\b/).size > 1
  end

  def summary(locale: I18n.locale)
    return unless requested? && !ambiguous?

    [ plan.variant&.display_name, plan.quantity && I18n.t("photo_recognition.quantity", count: plan.quantity, locale: locale) ].compact.join(", ").presence
  end

  def text
    return "" unless requested?

    normalized = caption.tr("০১২৩৪৫৬৭৮৯", "0123456789").gsub(/\b(?:this|that) one\b/i, "")
    Constants::PhotoRecognition::CAPTION_WORDS.each do |word, replacement|
      normalized = normalized.gsub(/(?<!\p{L})#{Regexp.escape(word)}(?!\p{L})/u, replacement)
    end
    normalized.gsub(/(?<=\d)\s*(?:টা|টি)/, " pcs").squish
  end

  def plan
    @plan ||= ConversationActionPlanner.new(message: Struct.new(:content).new(text),
      business: product.business, current_product: product).call
  end

  private

  attr_reader :product, :caption
end
