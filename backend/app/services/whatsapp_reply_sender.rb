require "net/http"

class WhatsappReplySender
  Result = Struct.new(
    :delivered, :skipped, :retryable, :status, :response_body, :external_message_id, :error,
    keyword_init: true
  )

  def initialize(recipient_id:, phone_number_id:, content:, access_token: ENV["WHATSAPP_ACCESS_TOKEN"])
    @recipient_id = recipient_id
    @phone_number_id = phone_number_id
    @content = content
    @access_token = access_token
  end

  def deliver
    return skipped_result("WHATSAPP_ACCESS_TOKEN is not configured") if access_token.blank?
    return skipped_result("WHATSAPP_PHONE_NUMBER_ID is not configured") if phone_number_id.blank?

    response = perform_request
    parsed_body = JSON.parse(response.body.presence || "{}")
    successful = response.is_a?(Net::HTTPSuccess)
    Result.new(
      delivered: successful,
      skipped: false,
      retryable: retryable_status?(response.code.to_i),
      status: response.code.to_i,
      response_body: parsed_body,
      external_message_id: parsed_body.dig("messages", 0, "id"),
      error: successful ? nil : "WhatsApp API returned HTTP #{response.code}"
    )
  rescue JSON::ParserError
    Result.new(
      delivered: false, skipped: false, retryable: retryable_status?(response&.code.to_i),
      status: response&.code&.to_i, response_body: {}, error: "WhatsApp API returned invalid JSON"
    )
  rescue Net::OpenTimeout, Net::ReadTimeout, Timeout::Error, SocketError,
    Errno::ECONNRESET, Errno::ECONNREFUSED, EOFError => error
    Result.new(delivered: false, skipped: false, retryable: true, response_body: {}, error: error.message)
  end

  private

  attr_reader :recipient_id, :phone_number_id, :content, :access_token

  def perform_request
    uri = URI(format(
      Constants::Meta::WHATSAPP_MESSAGES_URL,
      version: Constants::Meta::GRAPH_API_VERSION,
      phone_number_id: phone_number_id
    ))
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{access_token}"
    request["Content-Type"] = "application/json"
    request.body = request_payload.to_json
    Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }
  end

  def request_payload
    {
      messaging_product: "whatsapp",
      recipient_type: "individual",
      to: recipient_id,
      type: "text",
      text: { preview_url: false, body: content }
    }
  end

  def retryable_status?(status)
    status.in?(Constants::Meta::RETRYABLE_STATUS_CODES) || status >= 500
  end

  def skipped_result(error)
    Result.new(delivered: false, skipped: true, retryable: false, response_body: {}, error: error)
  end
end
