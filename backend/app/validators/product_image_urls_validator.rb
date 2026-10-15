require "uri"

class ProductImageUrlsValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    unless value.is_a?(Array)
      record.errors.add(attribute, :invalid_image_urls)
      return
    end
    if value.size > Constants::ProductImages::MAX_IMAGES
      record.errors.add(attribute, :too_many_images, count: Constants::ProductImages::MAX_IMAGES)
    end
    value.each_with_index do |url, index|
      unless self.class.valid_url?(url)
        record.errors.add(attribute, :invalid_image_url, position: index + 1, max_length: Constants::ProductImages::MAX_URL_LENGTH)
      end
    end
  end

  def self.valid_url?(url)
    return false unless url.is_a?(String) && url.length <= Constants::ProductImages::MAX_URL_LENGTH

    uri = URI.parse(url)
    uri.is_a?(URI::HTTPS) && uri.userinfo.nil? && uri.port == 443 &&
      uri.host.to_s.match?(Constants::ProductImages::PUBLIC_HOST) &&
      Constants::ProductImages::LOCAL_SUFFIXES.none? { |suffix| uri.host.downcase.end_with?(suffix) }
  rescue URI::InvalidURIError
    false
  end
end
