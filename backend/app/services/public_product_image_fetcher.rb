require "net/http"
require "resolv"
require "ipaddr"
require "base64"

class PublicProductImageFetcher
  Image = Data.define(:mime_type, :data)
  class UnsafeImage < StandardError; end
  BLOCKED_NETWORKS = %w[
    0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16
    172.16.0.0/12 192.0.0.0/24 192.0.2.0/24 192.168.0.0/16 198.18.0.0/15
    198.51.100.0/24 203.0.113.0/24 224.0.0.0/4 240.0.0.0/4
  ].map { |network| IPAddr.new(network) }.freeze
  PUBLIC_IPV6 = IPAddr.new("2000::/3")
  BLOCKED_IPV6 = %w[2001::/23 2001:db8::/32 2002::/16].map { |network| IPAddr.new(network) }.freeze
  ALLOWED_MIME_TYPES = %w[image/jpeg image/png image/webp].freeze

  def fetch(url)
    raise UnsafeImage unless ProductImageUrlsValidator.valid_url?(url)

    uri = URI(url)
    addresses = resolve_addresses(uri.host)
    raise UnsafeImage if addresses.empty? || addresses.any? { |address| !public_address?(address) }

    # Pin the validated address, retaining the original hostname for TLS/SNI.
    http = Net::HTTP.new(uri.host, uri.port, nil)
    http.ipaddr = addresses.first
    http.use_ssl = true
    http.open_timeout = 2
    http.read_timeout = 3
    http.write_timeout = 3
    bytes = +"".b
    mime = nil
    deadline = monotonic_time + Constants::PhotoRecognition::IMAGE_TIMEOUT_SECONDS
    http.request(Net::HTTP::Get.new(uri.request_uri)) do |response|
      raise UnsafeImage unless response.is_a?(Net::HTTPSuccess)

      mime = response["content-type"].to_s.split(";").first
      raise UnsafeImage unless ALLOWED_MIME_TYPES.include?(mime)
      raise UnsafeImage if response["content-length"].to_i > Constants::PhotoRecognition::MAX_IMAGE_BYTES

      response.read_body do |chunk|
        raise UnsafeImage if bytes.bytesize + chunk.bytesize > Constants::PhotoRecognition::MAX_IMAGE_BYTES || monotonic_time > deadline

        bytes << chunk
      end
    end
    raise UnsafeImage unless valid_signature?(bytes, mime)

    Image.new(mime_type: mime, data: Base64.strict_encode64(bytes))
  end

  private

  def resolve_addresses(host)
    Resolv::DNS.open do |resolver|
      resolver.timeouts = 2
      resolver.getaddresses(host).map(&:to_s)
    end
  end

  def monotonic_time
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def public_address?(address)
    ip = IPAddr.new(address)
    return BLOCKED_NETWORKS.none? { |network| network.include?(ip) } if ip.ipv4?

    PUBLIC_IPV6.include?(ip) && BLOCKED_IPV6.none? { |network| network.include?(ip) }
  end

  def valid_signature?(bytes, mime)
    case mime
    when "image/jpeg" then bytes.start_with?("\xFF\xD8\xFF".b)
    when "image/png" then bytes.start_with?("\x89PNG\r\n\x1A\n".b)
    when "image/webp" then bytes.start_with?("RIFF") && bytes.byteslice(8, 4) == "WEBP"
    end
  end
end
