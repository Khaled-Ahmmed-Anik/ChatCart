require "net/http"

class MessengerCustomerProfile
  PROFILE_API_BASE = "https://graph.facebook.com/v21.0"

  def initialize(sender_id:, page_access_token: ENV["MESSENGER_PAGE_ACCESS_TOKEN"])
    @sender_id = sender_id
    @page_access_token = page_access_token
  end

  def name
    return if sender_id.blank? || page_access_token.blank?

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 3, read_timeout: 5) do |http|
      http.request(Net::HTTP::Get.new(uri))
    end
    return unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)["name"].to_s.strip.presence
  rescue JSON::ParserError, Net::OpenTimeout, Net::ReadTimeout, Timeout::Error, SocketError,
    Errno::ECONNRESET, Errno::ECONNREFUSED, EOFError
    nil
  end

  private

  attr_reader :sender_id, :page_access_token

  def uri
    URI("#{PROFILE_API_BASE}/#{CGI.escapeURIComponent(sender_id)}").tap do |profile_uri|
      profile_uri.query = URI.encode_www_form(fields: "name", access_token: page_access_token)
    end
  end
end
