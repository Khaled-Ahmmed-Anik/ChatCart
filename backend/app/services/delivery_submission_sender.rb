require "net/http"

class DeliverySubmissionSender
  Result = Data.define(:success, :retryable, :status, :external_reference, :error)

  def initialize(submission)
    @submission = submission
    @integration = submission.delivery_integration
  end

  def deliver
    return Result.new(success: true, retryable: false, status: 200, external_reference: nil, error: nil) if integration.provider == "manual"

    uri = URI(integration.endpoint_url)
    raise ArgumentError, "Delivery endpoint must use HTTPS" unless uri.is_a?(URI::HTTPS) || allow_http_for_local?(uri)

    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["Authorization"] = "Bearer #{integration.api_key}" if integration.api_key.present?
    request.body = payload.to_json
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 3, read_timeout: 8) do |http|
      http.request(request)
    end
    body = JSON.parse(response.body.presence || "{}") rescue {}
    success = response.is_a?(Net::HTTPSuccess)
    Result.new(
      success: success,
      retryable: response.code.to_i.in?([ 408, 429 ]) || response.code.to_i >= 500,
      status: response.code.to_i,
      external_reference: body["id"] || body["reference"],
      error: success ? nil : "Delivery API returned HTTP #{response.code}"
    )
  rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNRESET, Errno::ECONNREFUSED => error
    Result.new(success: false, retryable: true, status: nil, external_reference: nil, error: error.message)
  end

  private

  attr_reader :submission, :integration

  def payload
    order = submission.order
    {
      order_number: order.number,
      customer: { name: order.customer_name, phone: order.phone, address: order.address },
      amount: order.total.to_s,
      currency: order.currency,
      items: order.order_items.map { |item| { name: item.product_name, quantity: item.quantity } }
    }
  end

  def allow_http_for_local?(uri)
    !Rails.env.production? && uri.is_a?(URI::HTTP) && uri.host.in?(%w[localhost 127.0.0.1])
  end
end
