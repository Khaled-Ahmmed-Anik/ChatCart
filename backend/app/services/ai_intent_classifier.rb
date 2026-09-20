require "net/http"

class AiIntentClassifier
  API_URL = "https://generativelanguage.googleapis.com/v1beta/models/%{model}:generateContent"
  DEFAULT_MODEL = "gemini-3.5-flash-lite"
  MINIMUM_CONFIDENCE = 0.65
  Result = Data.define(
    :intent, :secondary_intents, :confidence, :entities, :language, :sentiment,
    :needs_clarification, :possible_intents
  ) do
    def initialize(secondary_intents: [], **attributes)
      super(secondary_intents: secondary_intents, **attributes)
    end

    def intents
      [ intent, *secondary_intents ].uniq
    end
  end

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
      secondary_intents: valid_secondary_intents(parsed.fetch("secondary_intents", []), primary: intent),
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
      Choose one primary registered intent and zero or more secondary intents when the message genuinely contains
      multiple requests. Put the order-changing intent first. Never return more than one order-changing intent.
      Extract only values explicitly stated by the customer.
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
      Remembered conversation state: #{conversation_memory.to_json}
      Available products: #{catalog.active.includes(:product_variants).order(:name).select { |product| product.total_available_stock.positive? }.map(&:name).join(", ")}
      Recent conversation:
      #{sanitized_history}
      Current customer message: #{sanitize(message.content)}
    CONTEXT
  end

  def sanitized_history
    recent_messages.last(10).map do |recent_message|
      "#{recent_message.sender_type}: #{sanitize(recent_message.content)}"
    end.join("\n")
  end

  def conversation_memory
    ConversationMemory.new(message.conversation).context
  end

  def catalog
    message.conversation.business.products
  end

  def sanitize(value)
    value.to_s.gsub(/\+?\d[\d\s().-]{6,}\d/, "[PHONE]").first(500)
  end

  def response_schema
    {
      type: "OBJECT",
      properties: {
        intent: { type: "STRING", enum: ConversationIntentRegistry::INTENTS },
        secondary_intents: {
          type: "ARRAY",
          items: { type: "STRING", enum: ConversationIntentRegistry::INTENTS }
        },
        confidence: { type: "NUMBER" },
        entities: {
          type: "OBJECT",
          properties: {
            product_name: { type: "STRING" },
            variant_name: { type: "STRING" },
            size: { type: "STRING" },
            quantity: { type: "INTEGER" },
            minimum_price: { type: "NUMBER" },
            maximum_price: { type: "NUMBER" },
            budget: { type: "NUMBER" },
            product_format: { type: "STRING", enum: %w[single combo] },
            recipient: { type: "STRING" },
            scent_families: { type: "ARRAY", items: { type: "STRING" } },
            avoid_scent_families: { type: "ARRAY", items: { type: "STRING" } },
            occasions: { type: "ARRAY", items: { type: "STRING" } },
            projection: { type: "STRING" },
            performance: { type: "STRING" },
            selection_reference: { type: "STRING" },
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
      required: %w[intent secondary_intents confidence entities language sentiment needs_clarification possible_intents]
    }
  end

  def valid_possible_intents(intents)
    Array(intents).select { |intent| ConversationIntentRegistry.valid?(intent) }.first(3)
  end

  def valid_secondary_intents(intents, primary:)
    valid = Array(intents).select { |intent| ConversationIntentRegistry.valid?(intent) }.uniq - [ primary ]
    mutating = valid.select { |intent| intent.in?(ConversationIntentRegistry::MUTATING_INTENTS) }
    informational = valid.select { |intent| intent.in?(ConversationIntentRegistry::INFORMATIONAL_INTENTS) }
    allowed_mutating = primary.in?(ConversationIntentRegistry::MUTATING_INTENTS) ? [] : mutating.first(1)
    (allowed_mutating + informational).first(3)
  end
end
