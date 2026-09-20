require "net/http"
require "resolv"
require "ipaddr"

class PublicProductPageFetcher
  MAX_REDIRECTS = 3
  MAX_BYTES = 2.megabytes
  BLOCKED_NETWORKS = %w[
    0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16
    172.16.0.0/12 192.0.0.0/24 192.168.0.0/16 224.0.0.0/4
    ::/128 ::1/128 fc00::/7 fe80::/10 ff00::/8
  ].map { |network| IPAddr.new(network) }.freeze

  Response = Data.define(:url, :body, :content_type)

  def fetch(url, redirects: 0)
    raise ArgumentError, "Too many redirects" if redirects > MAX_REDIRECTS

    uri = validated_uri(url)
    response = request(uri)
    if response.is_a?(Net::HTTPRedirection)
      return fetch(URI.join(uri, response.fetch("location")).to_s, redirects: redirects + 1)
    end
    raise ArgumentError, "Source returned HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)
    raise ArgumentError, "Source response is too large" if response.body.bytesize > MAX_BYTES

    Response.new(url: uri.to_s, body: response.body, content_type: response["content-type"].to_s)
  end

  private

  def validated_uri(url)
    uri = URI.parse(url.to_s)
    raise ArgumentError, "Only public HTTP or HTTPS URLs are supported" unless uri.is_a?(URI::HTTP)
    raise ArgumentError, "URL credentials are not supported" if uri.userinfo.present?
    raise ArgumentError, "Unsupported URL port" unless uri.port.in?([ 80, 443 ])

    addresses = Resolv.getaddresses(uri.host)
    raise ArgumentError, "Could not resolve source host" if addresses.empty?
    if addresses.any? { |address| blocked_address?(address) }
      raise ArgumentError, "Private or local source URLs are not allowed"
    end

    uri
  rescue URI::InvalidURIError
    raise ArgumentError, "Invalid product URL"
  end

  def blocked_address?(address)
    ip = IPAddr.new(address)
    BLOCKED_NETWORKS.any? { |network| network.include?(ip) }
  end

  def request(uri)
    request = Net::HTTP::Get.new(uri)
    request["Accept"] = "text/html, application/json"
    request["User-Agent"] = "ChatCartProductImporter/1.0"
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 4, read_timeout: 8) do |http|
      http.request(request)
    end
  end
end
