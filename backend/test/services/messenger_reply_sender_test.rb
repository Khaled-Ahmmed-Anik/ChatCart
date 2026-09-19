require "test_helper"
require "net/http"

class MessengerReplySenderTest < ActiveSupport::TestCase
  test "skips delivery when page access token is missing" do
    result = MessengerReplySender.new(
      recipient_id: "fb-user-123",
      content: "Hello",
      page_access_token: nil
    ).deliver

    assert_not result.delivered
    assert result.skipped
    assert_not result.retryable
    assert_equal "MESSENGER_PAGE_ACCESS_TOKEN is not configured", result.error
  end

  test "posts text message to facebook send api" do
    response = fake_response(success: true, code: 200, body: '{"recipient_id":"fb-user-123","message_id":"mid-123"}')

    with_http_post_stub(->(*) { response }) do
      result = MessengerReplySender.new(
        recipient_id: "fb-user-123",
        content: "Hello",
        page_access_token: "token-123"
      ).deliver

      assert result.delivered
      assert_not result.skipped
      assert_not result.retryable
      assert_equal 200, result.status
      assert_equal response.body, result.response_body
    end
  end

  test "sends expected request uri and payload" do
    captured_uri = nil
    captured_body = nil
    captured_headers = nil
    response = fake_response(success: true, code: 200)

    with_http_post_stub(->(uri, body, headers) {
      captured_uri = uri
      captured_body = JSON.parse(body)
      captured_headers = headers
      response
    }) do
      MessengerReplySender.new(
        recipient_id: "fb-user-123",
        content: "Hello",
        page_access_token: "token-123"
      ).deliver
    end

    assert_equal "graph.facebook.com", captured_uri.host
    assert_equal "/v21.0/me/messages", captured_uri.path
    assert_equal "access_token=token-123", captured_uri.query
    assert_equal "application/json", captured_headers["Content-Type"]
    assert_equal "fb-user-123", captured_body.dig("recipient", "id")
    assert_equal "Hello", captured_body.dig("message", "text")
    assert_equal "RESPONSE", captured_body["messaging_type"]
  end

  test "returns failed result when facebook send api is not successful" do
    response = fake_response(success: false, code: 401, body: '{"error":"invalid token"}')

    with_http_post_stub(->(*) { response }) do
      result = MessengerReplySender.new(
        recipient_id: "fb-user-123",
        content: "Hello",
        page_access_token: "bad-token"
      ).deliver

      assert_not result.delivered
      assert_not result.skipped
      assert_not result.retryable
      assert_equal 401, result.status
      assert_equal response.body, result.response_body
    end
  end

  test "returns failed result when request raises" do
    with_http_post_stub(->(*) { raise SocketError, "network unavailable" }) do
      result = MessengerReplySender.new(
        recipient_id: "fb-user-123",
        content: "Hello",
        page_access_token: "token-123"
      ).deliver

      assert_not result.delivered
      assert_not result.skipped
      assert result.retryable
      assert_equal "network unavailable", result.error
    end
  end

  test "marks rate limits and server errors as retryable" do
    [ 429, 500, 503 ].each do |status|
      response = fake_response(success: false, code: status)

      with_http_post_stub(->(*) { response }) do
        result = MessengerReplySender.new(
          recipient_id: "fb-user-123",
          content: "Hello",
          page_access_token: "token-123"
        ).deliver

        assert result.retryable
        assert_equal status, result.status
      end
    end
  end

  private

  def fake_response(success:, code:, body: "")
    Struct.new(:success, :code, :body) do
      def is_a?(klass)
        klass == Net::HTTPSuccess ? success : super
      end
    end.new(success, code.to_s, body)
  end

  def with_http_post_stub(stub)
    original_post = Net::HTTP.method(:post)
    Net::HTTP.define_singleton_method(:post, &stub)
    yield
  ensure
    Net::HTTP.define_singleton_method(:post, original_post)
  end
end
