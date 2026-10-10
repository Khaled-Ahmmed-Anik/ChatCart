require "net/http"

class KnowledgeEmbeddingClient
  API_URL = "https://generativelanguage.googleapis.com/v1beta/models/%{model}:embedContent"
  DEFAULT_MODEL = "gemini-embedding-001"
  OUTPUT_DIMENSIONS = 768

  def initialize(api_key: ENV["GEMINI_API_KEY"], model: ENV["GEMINI_EMBEDDING_MODEL"])
    @api_key = api_key
    @model = model.presence || DEFAULT_MODEL
  end

  def embed(text:, task_type: "RETRIEVAL_DOCUMENT")
    raise ArgumentError, "GEMINI_API_KEY is required for embeddings" if api_key.blank?
    raise ArgumentError, "embedding text is blank" if text.blank?

    uri = URI(format(API_URL, model: model))
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["x-goog-api-key"] = api_key
    request.body = {
      model: "models/#{model}", taskType: task_type,
      content: { parts: [ { text: text } ] }, outputDimensionality: OUTPUT_DIMENSIONS
    }.to_json
    response = http_for(uri).request(request)
    raise KeyError, "Gemini embeddings returned HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    values = JSON.parse(response.body).dig("embedding", "values")
    raise KeyError, "Gemini embeddings response did not include values" unless values.is_a?(Array) && values.any?

    values.map(&:to_f)
  end

  attr_reader :model

  private

  attr_reader :api_key

  def http_for(uri)
    Net::HTTP.new(uri.host, uri.port).tap do |http|
      http.use_ssl = true
      http.open_timeout = 2
      http.read_timeout = 8
    end
  end
end
