require "test_helper"

class KnowledgeEmbeddingClientTest < ActiveSupport::TestCase
  test "requests a retrieval embedding with bounded dimensions" do
    response = Struct.new(:body, :code) do
      def is_a?(klass) = klass == Net::HTTPSuccess ? true : super
    end.new({ embedding: { values: [ 0.1, 0.2, 0.3 ] } }.to_json, "200")
    captured_request = nil
    fake_http = Object.new
    fake_http.define_singleton_method(:request) do |request|
      captured_request = request
      response
    end
    client = KnowledgeEmbeddingClient.new(api_key: "test-key")
    client.define_singleton_method(:http_for) { |_uri| fake_http }

    assert_equal [ 0.1, 0.2, 0.3 ], client.embed(text: "Product details")
    body = JSON.parse(captured_request.body)
    assert_equal "RETRIEVAL_DOCUMENT", body["taskType"]
    assert_equal 768, body["outputDimensionality"]
    assert_equal "test-key", captured_request["x-goog-api-key"]
  end

  test "requires an API key without making a request" do
    error = assert_raises(ArgumentError) do
      KnowledgeEmbeddingClient.new(api_key: nil).embed(text: "Product details")
    end

    assert_match "GEMINI_API_KEY", error.message
  end
end
