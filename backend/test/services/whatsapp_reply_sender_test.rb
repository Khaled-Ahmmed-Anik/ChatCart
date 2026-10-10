require "test_helper"
require "net/http"

class WhatsappReplySenderTest < ActiveSupport::TestCase
  test "skips delivery without an access token" do
    result = WhatsappReplySender.new(
      recipient_id: "8801712345678", phone_number_id: "phone-1", content: "Hello", access_token: nil
    ).deliver

    assert result.skipped
    assert_not result.delivered
    assert_equal "WHATSAPP_ACCESS_TOKEN is not configured", result.error
  end

  test "sends the expected WhatsApp Cloud API request" do
    captured_request = nil
    ssl_enabled = nil
    response = fake_response(success: true, code: 200, body: '{"messages":[{"id":"wamid.sent-1"}]}')

    with_http_start_stub(->(_host, _port, use_ssl:, &block) {
      ssl_enabled = use_ssl
      fake_http = Object.new
      fake_http.define_singleton_method(:request) do |request|
        captured_request = request
        response
      end
      block.call(fake_http)
    }) do
      result = WhatsappReplySender.new(
        recipient_id: "8801712345678", phone_number_id: "phone-1", content: "Hello", access_token: "token-1"
      ).deliver

      assert result.delivered
      assert_equal "wamid.sent-1", result.external_message_id
    end

    assert ssl_enabled
    body = JSON.parse(captured_request.body)
    assert_equal "/v21.0/phone-1/messages", captured_request.path
    assert_equal "Bearer token-1", captured_request["Authorization"]
    assert_equal "whatsapp", body["messaging_product"]
    assert_equal "8801712345678", body["to"]
    assert_equal "Hello", body.dig("text", "body")
  end

  test "marks throttling and server failures as retryable" do
    [ 429, 500, 503 ].each do |status|
      response = fake_response(success: false, code: status, body: '{"error":{}}')
      with_sender_response(response) do
        result = WhatsappReplySender.new(
          recipient_id: "8801712345678", phone_number_id: "phone-1", content: "Hello", access_token: "token-1"
        ).deliver
        assert result.retryable
        assert_equal status, result.status
      end
    end
  end

  test "retries a server failure even when its response is not JSON" do
    response = fake_response(success: false, code: 503, body: "upstream unavailable")

    with_sender_response(response) do
      result = WhatsappReplySender.new(
        recipient_id: "8801712345678", phone_number_id: "phone-1", content: "Hello", access_token: "token-1"
      ).deliver

      assert result.retryable
      assert_equal 503, result.status
      assert_equal "WhatsApp API returned invalid JSON", result.error
    end
  end

  private

  def with_sender_response(response, &test_block)
    with_http_start_stub(->(_host, _port, **_options, &block) {
      fake_http = Object.new
      fake_http.define_singleton_method(:request) { |_request| response }
      block.call(fake_http)
    }, &test_block)
  end

  def fake_response(success:, code:, body: "")
    Struct.new(:success, :code, :body) do
      def is_a?(klass)
        klass == Net::HTTPSuccess ? success : super
      end
    end.new(success, code.to_s, body)
  end

  def with_http_start_stub(stub)
    original_start = Net::HTTP.method(:start)
    Net::HTTP.define_singleton_method(:start, &stub)
    yield
  ensure
    Net::HTTP.define_singleton_method(:start, original_start)
  end
end
