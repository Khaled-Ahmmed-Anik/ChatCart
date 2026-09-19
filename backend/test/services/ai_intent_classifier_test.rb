require "test_helper"
require "net/http"

class AiIntentClassifierTest < ActiveSupport::TestCase
  test "classifies a Banglish repeat-order request into structured data" do
    classifier = build_classifier(content: "ager order ta abar korte chai", api_key: "gemini-key")
    response = fake_response(
      code: 200,
      result: {
        intent: "repeat_order",
        confidence: 0.96,
        entities: {},
        language: "banglish",
        sentiment: "neutral",
        needs_clarification: false
      }
    )

    with_http_stub(->(*) { response }) do
      result = classifier.classify

      assert_equal "repeat_order", result.intent
      assert_in_delta 0.96, result.confidence
      assert_equal "banglish", result.language
      assert_not result.needs_clarification
    end
  end

  test "forces clarification when confidence is below the threshold" do
    classifier = build_classifier(content: "oi ta den", api_key: "gemini-key")
    response = fake_response(
      code: 200,
      result: {
        intent: "select_product",
        confidence: 0.4,
        entities: {},
        language: "banglish",
        sentiment: "neutral",
        needs_clarification: false
      }
    )

    with_http_stub(->(*) { response }) do
      result = classifier.classify

      assert result.present?
      assert result.needs_clarification
    end
  end

  test "does not call Gemini without an API key" do
    assert_nil build_classifier(content: "hello", api_key: nil).classify
  end

  test "falls back when Gemini returns an unsupported intent" do
    classifier = build_classifier(content: "give me a discount", api_key: "gemini-key")
    response = fake_response(
      code: 200,
      result: {
        intent: "invent_discount",
        confidence: 0.99,
        entities: {},
        language: "english",
        sentiment: "neutral",
        needs_clarification: false
      }
    )

    with_http_stub(->(*) { response }) do
      assert_nil classifier.classify
    end
  end

  test "redacts phone numbers from recent context" do
    classifier = build_classifier(content: "amar order koi?", api_key: "gemini-key", history: [ "My phone is 01712345678" ])
    captured_request = nil
    response = fake_response(
      code: 200,
      result: {
        intent: "order_status",
        confidence: 0.9,
        entities: {},
        language: "banglish",
        sentiment: "neutral",
        needs_clarification: false
      }
    )

    with_http_stub(->(request) {
      captured_request = request
      response
    }) do
      classifier.classify
    end

    assert_includes captured_request.body, "[PHONE]"
    assert_not_includes captured_request.body, "01712345678"
    assert_equal "gemini-key", captured_request["x-goog-api-key"]
    assert_not_includes captured_request.uri.to_s, "gemini-key"
  end

  private

  def build_classifier(content:, api_key:, history: [])
    conversation = Conversation.create!(channel: "facebook", external_customer_id: SecureRandom.uuid)
    history.each { |text| conversation.messages.create!(sender_type: :customer, content: text) }
    message = conversation.messages.create!(sender_type: :customer, content: content)
    AiIntentClassifier.new(
      message: message,
      pending_order: conversation.create_pending_order!,
      recent_messages: conversation.messages.order(:id),
      api_key: api_key,
      model: "gemini-3.5-flash-lite"
    )
  end

  def fake_response(code:, result:)
    body = {
      candidates: [ { content: { parts: [ { text: result.to_json } ] } } ]
    }.to_json
    Struct.new(:code, :body) do
      def is_a?(klass)
        klass == Net::HTTPSuccess ? code.to_i.between?(200, 299) : super
      end
    end.new(code.to_s, body)
  end

  def with_http_stub(request_handler)
    fake_http = Object.new
    fake_http.define_singleton_method(:use_ssl=) { |_value| }
    fake_http.define_singleton_method(:open_timeout=) { |_value| }
    fake_http.define_singleton_method(:read_timeout=) { |_value| }
    fake_http.define_singleton_method(:request, &request_handler)
    original_new = Net::HTTP.method(:new)
    Net::HTTP.define_singleton_method(:new) { |*_arguments| fake_http }
    yield
  ensure
    Net::HTTP.define_singleton_method(:new, original_new)
  end
end
