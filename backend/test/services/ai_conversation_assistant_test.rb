require "test_helper"
require "net/http"

class AiConversationAssistantTest < ActiveSupport::TestCase
  test "includes only the explicitly remembered form of address in the rewrite prompt" do
    order = create_pending_order(product: create_product, status: :collecting_quantity)
    message = order.conversation.messages.create!(sender_type: :customer, content: "Bhai, eta nibo")
    assistant = AiConversationAssistant.new(
      customer_message: message,
      pending_order: order,
      outcome: :product_selected,
      address_preference: "bhai",
      api_key: "gemini-key",
      model: "gemini-3.5-flash-lite"
    )
    captured_request = nil
    response = fake_response(code: 200, body: gemini_response(reply: "Ji bhai, Fresh Musk ৳750. Koyta niben?"))

    with_http_stub(->(request) { captured_request = request; response }) do
      assistant.rewrite(fallback: "Fresh Musk is ৳750. How many would you like?")
    end

    assert_includes captured_request.body, "Customer's preferred form of address: bhai"
    assert_includes captured_request.body, "Never infer gender"
    assert_includes captured_request.body, "Use search_business_knowledge"
  end

  test "uses the deterministic reply when no API key is configured" do
    assistant = build_assistant(api_key: nil)

    assert_equal "Approved reply", assistant.rewrite(fallback: "Approved reply")
  end

  test "rewrites an approved reply in the customer's conversational style" do
    assistant = build_assistant(api_key: "gemini-key", language: "banglish", tone: "calm_and_helpful")
    response = fake_response(
      code: 200,
      body: gemini_response(reply: "Sure bhai 😊 Fresh Musk er koyta bottle niben?")
    )
    captured_request = nil

    with_http_stub(->(request) {
      captured_request = request
      response
    }) do
      reply = assistant.rewrite(fallback: "Fresh Musk is available. How many bottles would you like?")

      assert_equal "Sure bhai 😊 Fresh Musk er koyta bottle niben?", reply
    end

    assert_equal "gemini-key", captured_request["x-goog-api-key"]
    assert_not_includes captured_request.uri.to_s, "gemini-key"
    request_body = JSON.parse(captured_request.body)
    assert_equal "application/json", request_body.dig("generationConfig", "responseMimeType")
    assert_includes request_body.dig("contents", 0, "parts", 0, "text"), "Customer message"
    assert_includes request_body.dig("contents", 0, "parts", 0, "text"), "Preferred language: banglish"
    assert_includes request_body.dig("contents", 0, "parts", 0, "text"), "Response tone: calm_and_helpful"
  end

  test "rejects an AI reply that drops protected order facts" do
    pending_order = create_pending_order(
      product: create_product(name: "Fresh Musk", price: 750),
      quantity: 2,
      customer_name: "Khaled",
      phone: "01712345678",
      address: "Dhaka",
      status: :awaiting_confirmation
    )
    assistant = build_assistant(api_key: "gemini-key", pending_order: pending_order)
    response = fake_response(code: 200, body: gemini_response(reply: "Looks good. Confirm korben?"))
    fallback = "2 × Fresh Musk, total ৳1500, Khaled, 01712345678, Dhaka. Reply confirm."

    with_http_stub(->(*) { response }) do
      assert_equal fallback, assistant.rewrite(fallback: fallback)
    end
  end

  test "falls back safely when Gemini is unavailable" do
    assistant = build_assistant(api_key: "gemini-key")

    with_http_stub(->(*) { raise Net::ReadTimeout }) do
      assert_equal "Approved reply", assistant.rewrite(fallback: "Approved reply")
    end
  end

  test "uses an allowlisted tool and records safe telemetry when planner rollout is enabled" do
    product = create_product(name: "Fresh Musk", price: 750)
    order = create_pending_order(product: product, status: :collecting_quantity)
    assistant = build_assistant(api_key: "gemini-key", pending_order: order)
    responses = [
      fake_response(code: 200, body: {
        candidates: [ { content: { role: "model", parts: [ {
          functionCall: { name: "get_product_details", args: { product_id: product.id } }
        } ] } } ]
      }.to_json),
      fake_response(code: 200, body: gemini_response(reply: "Fresh Musk is ৳750. How many bottles would you like?"))
    ]
    requests = []

    with_environment("CONVERSATION_PLANNER_ENABLED" => "true") do
      with_http_stub(->(request) { requests << JSON.parse(request.body); responses.shift }) do
        reply = assistant.rewrite(fallback: "Fresh Musk is ৳750. How many bottles would you like?")

        assert_equal "Fresh Musk is ৳750. How many bottles would you like?", reply
      end
    end

    assert_equal 2, requests.size
    tool_names = requests.first.fetch("tools").first.fetch("functionDeclarations").pluck("name")
    assert_includes tool_names, "search_business_knowledge"
    assert_equal "get_product_details", requests.second.dig("contents", 2, "parts", 0, "functionResponse", "name")
    assert_equal true, assistant.telemetry.fetch("planner_used")
    assert_equal [ "get_product_details" ], assistant.telemetry.fetch("tool_names")
    assert_nil assistant.telemetry.fetch("fallback_reason")
  end

  test "records why deterministic fallback was used" do
    assistant = build_assistant(api_key: nil)

    assistant.rewrite(fallback: "Approved reply")

    assert_equal "api_key_missing", assistant.telemetry.fetch("fallback_reason")
  end

  private

  def build_assistant(
    api_key:, pending_order: create_pending_order(status: :collecting_product), language: nil, tone: nil
  )
    message = pending_order.conversation.messages.create!(sender_type: :customer, content: "Fresh Musk koyta ache bhai?")
    AiConversationAssistant.new(
      customer_message: message,
      pending_order: pending_order,
      outcome: :stock_inquiry,
      language: language,
      tone: tone,
      api_key: api_key,
      model: "gemini-2.5-flash-lite"
    )
  end

  def create_pending_order(attributes = {})
    conversation = Conversation.create!(channel: "facebook", external_customer_id: SecureRandom.uuid)
    conversation.create_pending_order!(attributes)
  end

  def create_product(attributes = {})
    Product.create!({ name: "Fresh Musk", price: 750, stock_quantity: 10 }.merge(attributes))
  end

  def gemini_response(reply:)
    {
      candidates: [
        {
          content: {
            parts: [ { text: { reply: reply, language: "banglish" }.to_json } ]
          }
        }
      ]
    }.to_json
  end

  def fake_response(code:, body:)
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


  def with_environment(values)
    previous = values.to_h.transform_values { |_value| nil }
    values.each_key { |key| previous[key] = ENV[key] }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    previous.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end
