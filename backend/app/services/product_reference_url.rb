class ProductReferenceUrl
  def self.normalize(value)
    return unless ProductImageUrlsValidator.valid_url?(value)

    uri = URI.parse(value)
    uri.host = uri.host.downcase
    uri.host = "facebook.com" if Constants::ProductMedia::FACEBOOK_HOSTS.include?(uri.host.downcase) && uri.host != "fb.watch"
    uri.fragment = nil
    pairs = URI.decode_www_form(uri.query.to_s).reject do |key, _|
      key.start_with?("utm_", "__") || key.in?(%w[fbclid mibextid])
    end
    uri.query = pairs.empty? ? nil : URI.encode_www_form(pairs.sort)
    uri.path = uri.path.sub(%r{/+\z}, "") unless uri.path == "/"
    uri.to_s
  rescue URI::InvalidURIError, ArgumentError
    nil
  end

  def self.facebook?(value)
    Constants::ProductMedia::FACEBOOK_HOSTS.include?(URI.parse(value).host.to_s.downcase)
  rescue URI::InvalidURIError
    false
  end
end
