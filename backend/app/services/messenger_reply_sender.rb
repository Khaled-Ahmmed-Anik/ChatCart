require "net/http"

class MessengerReplySender
  SEND_API_URL = "https://graph.facebook.com/v21.0/me/messages"
  Result = Struct.new(:delivered, :skipped, :status, :response_body, :error, keyword_init: true)

  def initialize(recipient_id:, content:, page_access_token: ENV["MESSENGER_PAGE_ACCESS_TOKEN"])
    @recipient_id = recipient_id
    @content = content
    @page_access_token = page_access_token
  end

  def deliver
    return skipped_result if page_access_token.blank?

    response = Net::HTTP.post(
      send_api_uri,
      request_payload.to_json,
      "Content-Type" => "application/json"
    )

    Result.new(
      delivered: response.is_a?(Net::HTTPSuccess),
      skipped: false,
      status: response.code.to_i,
      response_body: response.body
    )
  rescue StandardError => error
    Result.new(
      delivered: false,
      skipped: false,
      error: error.message
    )
  end

  private

  attr_reader :recipient_id, :content, :page_access_token

  def skipped_result
    Result.new(
      delivered: false,
      skipped: true,
      error: "MESSENGER_PAGE_ACCESS_TOKEN is not configured"
    )
  end

  def send_api_uri
    uri = URI(SEND_API_URL)
    uri.query = URI.encode_www_form(access_token: page_access_token)
    uri
  end

  def request_payload
    {
      recipient: { id: recipient_id },
      message: { text: content },
      messaging_type: "RESPONSE"
    }
  end
end
