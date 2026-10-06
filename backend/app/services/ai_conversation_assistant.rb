require "net/http"

class AiConversationAssistant
  API_URL = "https://generativelanguage.googleapis.com/v1beta/models/%{model}:generateContent"
  DEFAULT_MODEL = "gemini-3.5-flash-lite"
  MAX_REPLY_LENGTH = 1_200
  MAX_TOOL_CALLS = 2

  def initialize(
    customer_message:, pending_order:, outcome:, language: nil, tone: nil, address_preference: nil, response_plan: nil,
    api_key: ENV["GEMINI_API_KEY"], model: ENV["GEMINI_MODEL"]
  )
    @customer_message = customer_message
    @pending_order = pending_order
    @outcome = outcome
    @language = language
    @tone = tone
    @address_preference = address_preference
    @response_plan = response_plan
    @api_key = api_key
    @model = model.presence || DEFAULT_MODEL
  end

  def rewrite(fallback:)
    @telemetry = base_telemetry
    return fallback_with_reason(fallback, "api_key_missing") if api_key.blank?
    return fallback_with_reason(fallback, "naturalizer_disabled") unless naturalizer_enabled?

    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    candidate = request_reply(fallback)
    @telemetry["latency_ms"] = elapsed_ms(started_at)
    return candidate if safe_reply?(candidate, fallback)

    fallback_with_reason(fallback, "guardrail_rejected")
  rescue StandardError => error
    log_fallback(error)
    fallback_with_reason(fallback, error.class.name)
  end

  attr_reader :telemetry

  private

  attr_reader :customer_message, :pending_order, :outcome, :language, :tone, :address_preference, :response_plan,
    :api_key, :model

  def request_reply(fallback)
    return request_tool_grounded_reply(fallback) if planner_enabled?

    parse_reply(request_json(request_body(fallback)))
  end

  def request_tool_grounded_reply(fallback)
    first_payload = request_json(request_body(fallback).merge(tools: [ { functionDeclarations: ConversationToolGateway.definitions } ]))
    candidate_content = first_payload.dig("candidates", 0, "content")
    calls = Array(candidate_content&.fetch("parts", nil)).filter_map { |part| part["functionCall"] }.first(MAX_TOOL_CALLS)
    return parse_reply(first_payload) if calls.empty?

    gateway = ConversationToolGateway.new(conversation: pending_order.conversation, pending_order: pending_order)
    tool_parts = calls.map do |call|
      result = gateway.call(call.fetch("name"), call.fetch("args", {}))
      (@tool_evidence ||= []) << result
      telemetry["tool_names"] << call.fetch("name")
      telemetry["knowledge_citations"].concat(knowledge_citations(result))
      { functionResponse: { name: call.fetch("name"), response: result } }
    end
    telemetry["planner_used"] = true
    follow_up = request_body(fallback)
    follow_up[:contents] = [
      request_body(fallback).fetch(:contents).first,
      candidate_content,
      { role: "user", parts: tool_parts }
    ]
    parse_reply(request_json(follow_up))
  end

  def request_json(body)
    uri = URI(format(API_URL, model: model))
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["x-goog-api-key"] = api_key
    request.body = body.to_json

    response = http_for(uri).request(request)
    raise KeyError, "Gemini returned HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  end

  def parse_reply(response_payload)
    structured_text = Array(response_payload.dig("candidates", 0, "content", "parts"))
      .filter_map { |part| part["text"] }.first
    raise KeyError, "Gemini response did not include text" if structured_text.blank?

    JSON.parse(structured_text).fetch("reply").to_s.strip
  end

  def http_for(uri)
    Net::HTTP.new(uri.host, uri.port).tap do |http|
      http.use_ssl = true
      http.open_timeout = 2
      http.read_timeout = 5
    end
  end

  def request_body(fallback)
    {
      systemInstruction: {
        parts: [ { text: system_prompt } ]
      },
      contents: [
        {
          role: "user",
          parts: [ { text: user_prompt(fallback) } ]
        }
      ],
      generationConfig: {
        temperature: 0.35,
        maxOutputTokens: 250,
        responseMimeType: "application/json",
        responseSchema: {
          type: "OBJECT",
          properties: {
            reply: { type: "STRING" },
            language: { type: "STRING", enum: %w[english banglish bengali] }
          },
          required: %w[reply language]
        }
      }
    }
  end

  def system_prompt
    <<~PROMPT.squish
      You rewrite customer-service replies for ChatCart, a Bangladesh Messenger shop.
      Match the customer's language: natural English, Bengali script, or Banglish written in Latin characters.
      Be warm, concise, and conversational, but do not claim to be human.
      Adapt to the customer's level of formality without copying spelling mistakes or becoming overly familiar.
      Ask at most one new question at a time. Do not repeat greetings, catalogues, or explanations already given.
      Respect the supplied form of address naturally, but do not repeat it in every sentence.
      Never infer gender or invent a title that was not supplied.
      Preserve every product name, quantity, price, phone number, address, and instruction exactly as provided.
      Never add discounts, promises, products, prices, stock, delivery times, or order facts.
      Use search_business_knowledge for descriptive product guidance, FAQs, and explanatory policy questions.
      Use the exact product, variant, policy, and order tools for prices, stock, delivery charges, and order facts.
      Treat tool citations as evidence metadata; do not expose internal IDs or claim knowledge not returned by a tool.
      Do not change the meaning or next requested order field. Return only the requested JSON object.
    PROMPT
  end

  def user_prompt(fallback)
    <<~PROMPT
      Customer message: #{customer_message.content.to_json}
      Order status: #{pending_order.status}
      Processing outcome: #{outcome}
      Structured response goal: #{response_plan&.goal || "answer_customer"}
      Required next question: #{response_plan&.pending_question || "none"}
      Approved facts: #{response_plan&.facts.to_h.to_json}
      Safe conversation context: #{ConversationMemory.new(pending_order.conversation).context.to_json}
      Recent bot replies to avoid repeating: #{recent_bot_replies.to_json}
      Preferred language: #{language || "match the customer"}
      Response tone: #{tone || "friendly"}
      Customer's preferred form of address: #{ConversationAddressPreference.display(address_preference) || "not specified"}
      Approved factual reply: #{fallback.to_json}

      Rewrite the approved reply in the customer's language and tone. Keep it under 600 characters unless it is an order summary.
    PROMPT
  end

  def safe_reply?(candidate, fallback)
    ConversationReplyGuard.new(
      candidate: candidate,
      fallback: fallback,
      pending_order: pending_order,
      response_plan: response_plan,
      tool_evidence: @tool_evidence,
      recent_replies: recent_bot_replies
    ).valid?
  end

  def log_fallback(error)
    MessengerSafeLogger.info(
      "ai_reply_fallback",
      conversation_id: pending_order.conversation_id,
      error_class: error.class.name
    )
  end

  def naturalizer_enabled?
    ConversationAiRollout.enabled?(:naturalizer, conversation: pending_order.conversation)
  end

  def planner_enabled?
    ConversationAiRollout.enabled?(:planner, conversation: pending_order.conversation)
  end

  def base_telemetry
    {
      "planner_used" => false, "tool_names" => [], "knowledge_citations" => [],
      "fallback_reason" => nil, "latency_ms" => nil
    }
  end

  def knowledge_citations(tool_result)
    return [] unless tool_result["tool"] == "search_business_knowledge"

    Array(tool_result.dig("result", "matches")).filter_map { |match| match["citation"] }
  end

  def fallback_with_reason(fallback, reason)
    @telemetry ||= base_telemetry
    @telemetry["fallback_reason"] = reason
    fallback
  end

  def elapsed_ms(started_at)
    ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1_000).round
  end

  def recent_bot_replies
    pending_order.conversation.messages.bot.order(created_at: :desc, id: :desc).limit(3).pluck(:content).map do |reply|
      reply.to_s.truncate(300)
    end
  end
end
