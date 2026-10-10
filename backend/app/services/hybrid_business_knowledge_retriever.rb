class HybridBusinessKnowledgeRetriever
  RANK_CONSTANT = 60.0
  DEFAULT_LIMIT = 5

  Result = Data.define(:document, :score, :lexical_rank, :semantic_rank) do
    def citation
      { knowledge_document_id: document.id, source_type: document.source_type, source_id: document.source_id,
        title: document.title }
    end
  end

  def initialize(business:, query:, source_types: nil, limit: DEFAULT_LIMIT,
    embedding_client: KnowledgeEmbeddingClient.new, semantic_enabled: nil)
    @business = business
    @query = query.to_s.squish
    @source_types = Array(source_types).presence
    @limit = limit.to_i.clamp(1, BusinessKnowledgeRetriever::MAXIMUM_LIMIT)
    @embedding_client = embedding_client
    @semantic_enabled = semantic_enabled.nil? ? configured? : semantic_enabled
  end

  def call
    lexical = lexical_results
    semantic = semantic_results
    return lexical.map.with_index { |result, index| build_result(result.document, index + 1, nil) } if semantic.empty?

    documents = (lexical.map(&:document) + semantic).uniq(&:id)
    lexical_ranks = lexical.map.with_index { |result, index| [ result.document.id, index + 1 ] }.to_h
    semantic_ranks = semantic.map.with_index { |document, index| [ document.id, index + 1 ] }.to_h
    documents.map do |document|
      build_result(document, lexical_ranks[document.id], semantic_ranks[document.id])
    end.sort_by { |result| [ -result.score, result.document.id ] }.first(limit)
  rescue ArgumentError, KeyError, Net::OpenTimeout, Net::ReadTimeout, Timeout::Error => error
    Rails.logger.info("knowledge_semantic_fallback error_class=#{error.class.name}")
    lexical_results.map.with_index { |result, index| build_result(result.document, index + 1, nil) }
  end

  private

  attr_reader :business, :query, :source_types, :limit, :embedding_client, :semantic_enabled

  def lexical_results
    @lexical_results ||= BusinessKnowledgeRetriever.new(
      business: business, query: query, source_types: source_types, limit: limit
    ).call
  end

  def semantic_results
    return [] unless semantic_enabled && query.present?

    candidates = business.knowledge_documents.active.where.not(embedding: [])
    candidates = candidates.where(source_type: source_types) if source_types
    candidates = candidates.to_a
    return [] if candidates.empty?

    query_vector = embedding_client.embed(text: query, task_type: "RETRIEVAL_QUERY")
    candidates.filter_map do |document|
      similarity = cosine_similarity(query_vector, document.embedding)
      [ document, similarity ] if similarity
    end.sort_by { |document, similarity| [ -similarity, document.id ] }.first(limit).map(&:first)
  end

  def build_result(document, lexical_rank, semantic_rank)
    score = rank_score(lexical_rank) + rank_score(semantic_rank)
    Result.new(document: document, score: score.round(6), lexical_rank: lexical_rank, semantic_rank: semantic_rank)
  end

  def rank_score(rank)
    rank ? 1.0 / (RANK_CONSTANT + rank) : 0.0
  end

  def cosine_similarity(left, right)
    return if left.empty? || left.size != right.size

    dot = left.zip(right).sum { |a, b| a.to_f * b.to_f }
    magnitude = Math.sqrt(left.sum { |value| value.to_f**2 }) * Math.sqrt(right.sum { |value| value.to_f**2 })
    magnitude.zero? ? nil : dot / magnitude
  end

  def configured?
    ActiveModel::Type::Boolean.new.cast(ENV.fetch("KNOWLEDGE_EMBEDDINGS_ENABLED", "false"))
  end
end
