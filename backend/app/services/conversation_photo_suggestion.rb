class ConversationPhotoSuggestion
  Result = Struct.new(:product, :reply_key, :details, keyword_init: true)

  def initialize(conversation)
    @conversation = conversation
  end

  def offer!(product:, reply:, event:)
    clear!
    return unless product

    conversation.update!(conversation_state: state.merge("photo_suggestion" => {
      "product_id" => product.id, "reply_id" => reply.id, "event_id" => event.id,
      "expires_at" => Constants::PhotoRecognition::SUGGESTION_LIFETIME.from_now.iso8601
    }))
  end

  def resolve(message:, pending_order:)
    return unless conversation.channel == "facebook"

    text = message.content.to_s.unicode_normalize(:nfkc).downcase.squish
    accepts = text.match?(Constants::PhotoRecognition::PHOTO_ACCEPTANCE) || photo_command?(text, Constants::Conversation::EXPLICIT_CONFIRMATION)
    rejects = text.match?(Constants::PhotoRecognition::PHOTO_REJECTION) || photo_command?(text, Constants::Conversation::EXPLICIT_CANCELLATION)
    unless accepts || rejects
      clear!
      return
    end
    reply = conversation.messages.where(sender_type: %i[bot seller]).order(created_at: :desc, id: :desc).first
    unless reply&.bot? && reply.metadata["photo_recognition"] == true
      clear!
      return
    end

    offer = state["photo_suggestion"].to_h
    clear!
    return Result.new(product: nil, reply_key: "rejected") if rejects
    source = valid_offer_source(offer, reply)
    return Result.new(product: nil, reply_key: "expired") unless source
    product = conversation.business.products.available_for_sale.find_by(id: offer["product_id"])
    return Result.new(product: nil, reply_key: "unavailable") unless product && product.total_available_stock.positive?

    details = ConversationPhotoOrderDetails.new(product: product, caption: source.photo_caption)
    return Result.new(reply_key: "caption_clarification") if details.ambiguous?
    if pending_order && (!pending_order.collecting_product? || pending_order.product_id || pending_order.pending_order_items.exists?)
      locked = pending_order.confirmed? || pending_order.submitted_to_woocommerce? || pending_order.cancelled?
      return Result.new(reply_key: "existing_order") if locked || !details.addition?
    end

    Result.new(product: product, details: details)
  end

  def reply_text(key, **options)
    I18n.t("photo_recognition.#{key}", locale: locale, **options)
  end

  def match_reply(product:, event:)
    text = reply_text("match", product: product.name)
    details = ConversationPhotoOrderDetails.new(product: product, caption: event.photo_caption)
    summary = details.summary(locale: locale)
    return text unless summary

    "#{text}\n\n#{reply_text('caption_details', details: summary)}"
  end

  private

  attr_reader :conversation

  def locale
    language = state["preferred_language"].presence || conversation.business.default_language
    { "bengali" => :bn, "bn" => :bn, "banglish" => :banglish }.fetch(language, :en)
  end

  def state = conversation.conversation_state.to_h

  def photo_command?(text, pattern)
    text.match?(pattern) && !text.match?(Constants::PhotoRecognition::NAMED_ORDER_REFERENCE)
  end

  def clear!
    conversation.update!(conversation_state: state.except("photo_suggestion")) if state.key?("photo_suggestion")
  end

  def valid_offer_source(offer, reply)
    return unless conversation.business.active? && offer["reply_id"] == reply.id &&
      offer["product_id"] == reply.metadata["suggested_product_id"] && Time.iso8601(offer.fetch("expires_at")) > Time.current

    source = conversation.business.messenger_webhook_events.find_by(id: offer["event_id"], sender_id: conversation.external_customer_id, event_type: "customer_image")
    return unless source

    newer_photo = conversation.business.messenger_webhook_events.where(event_type: "customer_image", sender_id: conversation.external_customer_id)
      .where.not(status: "ignored").received_after(source).exists?
    source unless newer_photo
  rescue ArgumentError, KeyError, TypeError
    nil
  end
end
