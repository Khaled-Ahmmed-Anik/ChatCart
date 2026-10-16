class BusinessKnowledgeRetriever
  DEFAULT_LIMIT = 5
  MAXIMUM_LIMIT = 10
  QUESTION_WORDS = %w[what are is the a an do does you your our please tell me about how much can i we have].freeze
  SEARCH_VECTOR = "to_tsvector('simple', coalesce(title, '') || ' ' || coalesce(content, ''))"

  Result = Data.define(:document, :score) do
    def citation
      { knowledge_document_id: document.id, source_type: document.source_type, source_id: document.source_id,
        title: document.title }
    end
  end

  def initialize(business:, query:, source_types: nil, limit: DEFAULT_LIMIT)
    @business = business
    @query = query.to_s.squish
    words = @query.downcase.scan(/[\p{L}\p{M}\p{N}]+/u)
    @query = words.reject { |word| QUESTION_WORDS.include?(word) }.join(" ") unless @query.match?(/["-]|\bOR\b/)
    @source_types = Array(source_types).presence
    @limit = limit.to_i.clamp(1, MAXIMUM_LIMIT)
  end

  def call
    return [] if query.blank?

    ranked_scope.map do |document|
      Result.new(document: document, score: document.attributes.fetch("retrieval_score").to_f.round(4))
    end
  end

  private

  attr_reader :business, :query, :source_types, :limit

  def ranked_scope
    scope = business.knowledge_documents.active
    scope = scope.where(source_type: source_types) if source_types
    scope
      .where("#{SEARCH_VECTOR} @@ websearch_to_tsquery('simple', ?)", query)
      .select("knowledge_documents.*, ts_rank_cd(#{SEARCH_VECTOR}, websearch_to_tsquery('simple', #{quoted_query})) AS retrieval_score")
      .order(Arel.sql("retrieval_score DESC, knowledge_documents.id ASC"))
      .limit(limit)
  end

  def quoted_query
    ActiveRecord::Base.connection.quote(query)
  end
end
