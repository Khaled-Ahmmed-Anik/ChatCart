class ProductMediaValidator < ActiveModel::Validator
  def validate(record)
    attributes = record.product_attributes
    return unless attributes.is_a?(Hash)

    media = attributes.fetch(Constants::ProductMedia::KEY, [])
    links = attributes.fetch(Constants::ProductMedia::LINKS_KEY, [])
    valid_media = media.is_a?(Array) && media.size <= Constants::ProductMedia::MAX_ITEMS && media.all? do |item|
      item.is_a?(Hash) && ProductImageUrlsValidator.valid_url?(item["url"]) &&
        item["kind"].in?(Constants::ProductMedia::KINDS) && item["authenticity"].in?(Constants::ProductMedia::AUTHENTICITIES) &&
        (item["kind"] != "video" || !URI.parse(item["url"]).host.downcase.in?(Constants::ProductMedia::VIDEO_PAGE_HOSTS)) &&
        (item["variant"].nil? || item["variant"].is_a?(String) && item["variant"].length <= Constants::ProductMedia::MAX_VARIANT_LENGTH)
    end
    valid_links = links.is_a?(Array) && links.size <= Constants::ProductMedia::MAX_ITEMS &&
      links.all? { |url| ProductReferenceUrl.normalize(url).present? }
    record.errors.add(:product_attributes, :invalid_catalogue_media, count: Constants::ProductMedia::MAX_ITEMS) unless valid_media && valid_links
  end
end
