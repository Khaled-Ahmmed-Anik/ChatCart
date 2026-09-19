require "net/http"

class AiIntentClassifier
  API_URL = "https://generativelanguage.googleapis.com/v1beta/models/%{model}:generateContent"
  DEFAULT_MODEL = "gemini-3.5-flash-lite"
  MINIMUM_CONFIDENCE = 0.65
  Result = Data.define(:intent, :confidence, :entities, :language, :sentiment, :needs_clarification, :possible_intents)

  def initialize(message:, pending_order:, recent_messages:, api_key: ENV["GEMINI_API_KEY"], model: ENV["GEMINI_MODEL"])
    @message = message
    @pending_order = pending_order
    @recent_messages = recent_messages
    @api_key = api_key
    @model = model.presence || DEFAULT_MODEL
  end

  def classify
    return if api_key.blank?

    parsed = request_classification
    build_result(parsed)
  rescue StandardError => error
    MessengerSafeLogger.info(
      "ai_intent_fallback",
      conversation_id: message.conversation_id,
      error_class: error.class.name
    )
    nil
  end

  private

  attr_reader :message, :pending_order, :recent_messages, :api_key, :model

  def request_classification
    uri = URI(format(API_URL, model: model))
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["x-goog-api-key"] = api_key
    request.body = request_body.to_json
    response = http_for(uri).request(request)
    raise KeyError, "Gemini returned HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    payload = JSON.parse(response.body)
    text = payload.dig("candidates", 0, "content", "parts", 0, "text")
    raise KeyError, "Gemini response did not include text" if text.blank?

    JSON.parse(text)
  end

  def build_result(parsed)
    intent = parsed.fetch("intent")
    raise KeyError, "Unsupported intent" unless ConversationIntentRegistry.valid?(intent)

    confidence = parsed.fetch("confidence").to_f.clamp(0.0, 1.0)
    Result.new(
      intent: intent,
      confidence: confidence,
      entities: parsed.fetch("entities", {}).to_h.with_indifferent_access,
      language: parsed.fetch("language", "english"),
      sentiment: parsed.fetch("sentiment", "neutral"),
      needs_clarification: parsed.fetch("needs_clarification", false) || confidence < MINIMUM_CONFIDENCE,
      possible_intents: valid_possible_intents(parsed.fetch("possible_intents", []))
    )
  end

  def http_for(uri)
    Net::HTTP.new(uri.host, uri.port).tap do |http|
      http.use_ssl = true
      http.open_timeout = 2
      http.read_timeout = 5
    end
  end

  def request_body
    {
      systemInstruction: { parts: [ { text: system_prompt } ] },
      contents: [ { role: "user", parts: [ { text: classification_context } ] } ],
      generationConfig: {
        temperature: 0,
        maxOutputTokens: 300,
        responseMimeType: "application/json",
        responseSchema: response_schema
      }
    }
  end

  def system_prompt
    <<~PROMPT.squish
      Classify messages for a Bangladesh online shop. Understand English, Bengali script, and Banglish.
      Choose exactly one registered intent. Extract only values explicitly stated by the customer.
      Never invent products, quantities, personal details, prices, policies, or order facts.
      Set needs_clarification true when the request is ambiguous. When it is true, provide the two or three
      most likely registered intents in possible_intents; otherwise return an empty possible_intents array.
      Return only the requested JSON object.
    PROMPT
  end

  def classification_context
    <<~CONTEXT
      Registered intents: #{ConversationIntentRegistry::INTENTS.join(", ")}
      Current order status: #{pending_order&.status || "none"}
      Remembered conversation state: #{remembered_state.to_json}
      Available products: #{Product.active.in_stock.order(:name).pluck(:name).join(", ")}
      Recent conversation:
      #{sanitized_history}
      Current customer message: #{sanitize(message.content)}
    CONTEXT
  end

  def sanitized_history
    recent_messages.last(6).map do |recent_message|
      "#{recent_message.sender_type}: #{sanitize(recent_message.content)}"
    end.join("\n")
  end

  def remembered_state
    message.conversation.conversation_state.to_h.slice(
      "preferred_language", "pending_question", "last_intent", "last_outcome"
    )
  end

  def sanitize(value)
    value.to_s.gsub(/\+?\d[\d\s().-]{6,}\d/, "[PHONE]").first(500)
  end

  def response_schema
    {
      type: "OBJECT",
      properties: {
        intent: { type: "STRING", enum: ConversationIntentRegistry::INTENTS },
        confidence: { type: "NUMBER" },
        entities: {
          type: "OBJECT",
          properties: {
            product_name: { type: "STRING" },
            quantity: { type: "INTEGER" },
            customer_name: { type: "STRING" },
            phone: { type: "STRING" },
            address: { type: "STRING" },
            language: { type: "STRING" }
          }
        },
        language: { type: "STRING", enum: %w[english banglish bengali] },
        sentiment: { type: "STRING", enum: %w[positive neutral negative] },
        needs_clarification: { type: "BOOLEAN" },
        possible_intents: {
          type: "ARRAY",
          items: { type: "STRING", enum: ConversationIntentRegistry::INTENTS }
        }
      },
      required: %w[intent confidence entities language sentiment needs_clarification possible_intents]
    }
  end

  def valid_possible_intents(intents)
    Array(intents).select { |intent| ConversationIntentRegistry.valid?(intent) }.first(3)
  end
end
