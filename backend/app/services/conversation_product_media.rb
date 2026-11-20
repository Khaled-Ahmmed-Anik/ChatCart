class ConversationProductMedia
  Result = Data.define(:content, :attachments, :product, :outcome)

  def initialize(conversation:, message:)
    @conversation, @text = conversation, message.content.to_s
    language = ConversationLanguagePreference.choose(@text, conversation.conversation_state.to_h)
    @locale = language.in?(%w[bn bengali bangla]) ? "bn" : (language == "banglish" ? "banglish" : "en")
  end

  def call
    urls = @text.scan(Constants::ProductMedia::URL).map { |url| url.sub(/[.,!?)]+\z/, "") }
    media_request = @text.match?(Constants::ProductMedia::REQUEST)
    return unless media_request || urls.any?
    return reply(:channel_unavailable) if media_request && @conversation.channel != "facebook"

    products = @conversation.business.products.available_for_sale.includes(:product_variants).to_a
    linked = products.select do |product|
      saved = [ product.source_url, *Array(product.product_attributes.to_h[Constants::ProductMedia::LINKS_KEY]) ]
        .filter_map { |url| ProductReferenceUrl.normalize(url) }
      urls.any? { |url| saved.include?(ProductReferenceUrl.normalize(url)) }
    end
    return unless media_request || linked.any? || urls.any? { |url| ProductReferenceUrl.facebook?(url) }
    return reply(:unknown_link) if urls.any? && linked.empty?
    return reply(:choose_product) if linked.many?

    product = linked.first
    unless product
      resolution = ProductResolutionService.new(business: @conversation.business, query: @text).resolve
      return reply(:choose_product) if resolution.ambiguous?

      product = resolution.product if resolution.matched?
      unless product
        candidate = CatalogueConversationReference.new(conversation: @conversation, text: @text).product ||
          products.find { |item| item.id == @conversation.pending_order&.product_id }
        product = candidate if candidate && contextual_request?(candidate)
      end
    end
    return reply(:choose_product) unless product
    return reply(:linked_product, product: product, name: product.name, price: product.starting_price.to_s) unless media_request

    kind = @text.match?(Constants::ProductMedia::VIDEO_REQUEST) ? "video" : "image"
    actual = @text.match?(Constants::ProductMedia::ACTUAL_REQUEST)
    variant = CatalogueOptionResolver.call(product: product, text: @text)
    variant ||= @conversation.pending_order&.product_variant if @conversation.pending_order&.product_id == product.id
    return reply(:choose_variant, product: product) if !variant && @text.match?(Constants::ProductMedia::COLOUR_REQUEST)

    media = Array(product.product_attributes.to_h[Constants::ProductMedia::KEY]).select do |item|
      item.is_a?(Hash) && item["kind"] == kind && ProductImageUrlsValidator.valid_url?(item["url"]) &&
        item["authenticity"].in?(Constants::ProductMedia::AUTHENTICITIES) &&
        (!actual || item["authenticity"] == "actual") &&
        (variant ? item["variant"].to_s.casecmp?(variant.name) : item["variant"].blank?)
    end
    # Existing catalogue images are promotional/unverified, never actual-photo evidence.
    if media.empty? && kind == "image" && !actual && !variant
      media = product.image_urls.select { |url| ProductImageUrlsValidator.valid_url?(url) }.map do |url|
        { "url" => url, "kind" => "image", "authenticity" => "promotional" }
      end
    end
    return reply(:unavailable, product: product) if media.empty?

    selected = media.uniq { |item| item["url"] }.first(Constants::ProductMedia::MAX_ATTACHMENTS)
    label = selected.all? { |item| item["authenticity"] == "actual" } ? :actual : :catalogue
    reply(label, product: product, name: product.name,
      attachments: selected.map { |item| { "type" => kind, "url" => item["url"] } })
  end

  private

  def contextual_request?(product)
    normalized = ConversationTextNormalizer.call(@text)
    product.available_variants.each do |variant|
      normalized = normalized.gsub(/\b#{Regexp.escape(ConversationTextNormalizer.call(variant.name))}\b/, " ")
    end
    normalized = normalized.gsub(Constants::ProductMedia::COLOUR_REQUEST, " ")
    normalized = normalized.gsub(/আসল|ছবি|ভিডিও|দিন|দেন|দেখান|এটার|এর|এই|পণ্যের/, " ")
    (normalized.split - Constants::ProductMedia::CONTEXT_WORDS).empty?
  end

  def reply(key, product: nil, attachments: [], **values)
    Result.new(content: I18n.t("product_media.#{@locale}.#{key}", **values), attachments: attachments,
      product: product, outcome: :product_media_requested)
  end
end
