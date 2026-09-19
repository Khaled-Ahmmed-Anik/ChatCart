require "net/http"

class AiConversationAssistant
  API_URL = "https://generativelanguage.googleapis.com/v1beta/models/%{model}:generateContent"
  DEFAULT_MODEL = "gemini-3.5-flash-lite"
  MAX_REPLY_LENGTH = 1_200

  def initialize(
    customer_message:, pending_order:, outcome:, language: nil, tone: nil,
    api_key: ENV["GEMINI_API_KEY"], model: ENV["GEMINI_MODEL"]
  )
    @customer_message = customer_message
    @pending_order = pending_order
    @outcome = outcome
    @language = language
    @tone = tone
    @api_key = api_key
    @model = model.presence || DEFAULT_MODEL
  end

  def rewrite(fallback:)
    return fallback if api_key.blank?

    candidate = request_reply(fallback)
    safe_reply?(candidate, fallback) ? candidate : fallback
  rescue StandardError => error
    log_fallback(error)
    fallback
  end

  private

  attr_reader :customer_message, :pending_order, :outcome, :language, :tone, :api_key, :model

  def request_reply(fallback)
    uri = URI(format(API_URL, model: model))
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["x-goog-api-key"] = api_key
    request.body = request_body(fallback).to_json

    response = http_for(uri).request(request)
    raise KeyError, "Gemini returned HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    response_payload = JSON.parse(response.body)
    structured_text = response_payload.dig("candidates", 0, "content", "parts", 0, "text")
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
      Preserve every product name, quantity, price, phone number, address, and instruction exactly as provided.
      Never add discounts, promises, products, prices, stock, delivery times, or order facts.
      Do not change the meaning or next requested order field. Return only the requested JSON object.
    PROMPT
  end

  def user_prompt(fallback)
    <<~PROMPT
      Customer message: #{customer_message.content.to_json}
      Order status: #{pending_order.status}
      Processing outcome: #{outcome}
      Preferred language: #{language || "match the customer"}
      Response tone: #{tone || "friendly"}
      Approved factual reply: #{fallback.to_json}

      Rewrite the approved reply in the customer's language and tone. Keep it under 600 characters unless it is an order summary.
    PROMPT
  end

  def safe_reply?(candidate, fallback)
    return false if candidate.blank? || candidate.length > MAX_REPLY_LENGTH

    protected_facts(fallback).all? { |fact| candidate.include?(fact) }
  end

  def protected_facts(fallback)
    order_facts = [
      pending_order.product&.name,
      pending_order.quantity&.to_s,
      pending_order.customer_name,
      pending_order.phone,
      pending_order.address,
      formatted_total
    ].compact
    catalog_facts = pending_order.conversation.business.products.find_each.flat_map do |product|
      [ product.name, formatted_price(product.price) ]
    end

    (order_facts + catalog_facts).uniq.select { |fact| fallback.include?(fact) }
  end

  def formatted_total
    return if pending_order.product.blank? || pending_order.quantity.blank?

    amount = pending_order.total_price
    amount = amount.to_i if amount.frac.zero?
    "৳#{amount}"
  end

  def formatted_price(value)
    amount = value.to_d
    amount = amount.to_i if amount.frac.zero?
    "৳#{amount}"
  end

  def log_fallback(error)
    MessengerSafeLogger.info(
      "ai_reply_fallback",
      conversation_id: pending_order.conversation_id,
      error_class: error.class.name
    )
  end
end
