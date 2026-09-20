require "did_you_mean"

class ProductResolutionService
  STOP_WORDS = %w[the a an perfume fragrance attar bottle ta ti eta oi please chai want need den].freeze
  Candidate = Data.define(:product, :score, :matched_name)
  Result = Data.define(:status, :product, :confidence, :candidates) do
    def matched? = status == :matched
    def ambiguous? = status == :ambiguous
  end

  def initialize(business:, query:, recent_product_name: nil)
    @business = business
    @query = normalize(query)
    @recent_product_name = recent_product_name
  end

  def resolve
    ranked = candidates.sort_by { |candidate| -candidate.score }
    return Result.new(status: :not_found, product: nil, confidence: 0.0, candidates: []) if ranked.empty?

    best = ranked.first
    shared = shared_single_token_candidates(ranked)
    if best.score < 1.0 && shared.map(&:product).uniq.size > 1
      return Result.new(status: :ambiguous, product: nil, confidence: best.score, candidates: shared.first(4))
    end
    close = ranked.select { |candidate| candidate.score >= best.score - 0.06 }.first(4)
    if close.map(&:product).uniq.size > 1
      return Result.new(status: :ambiguous, product: nil, confidence: best.score, candidates: close)
    end

    threshold = meaningful_tokens.length <= 1 ? 0.82 : 0.68
    return Result.new(status: :not_found, product: nil, confidence: best.score, candidates: ranked.first(3)) if best.score < threshold

    Result.new(status: :matched, product: best.product, confidence: best.score, candidates: [ best ])
  end

  private

  attr_reader :business, :query, :recent_product_name

  def candidates
    business.products.available_for_sale.includes(:product_variants).filter_map do |product|
      next unless product.total_available_stock.positive?

      name, candidate_score = product.searchable_names.map { |search_name| [ search_name, score(search_name) ] }.max_by(&:last)
      Candidate.new(product: product, score: candidate_score, matched_name: name) if candidate_score.positive?
    end
  end

  def score(name)
    normalized_name = normalize(name)
    name_tokens = tokens(normalized_name)
    return 1.0 if query == normalized_name
    return 0.97 if compact(query) == compact(normalized_name)
    return 0.94 if query.match?(/(?:\A|\s)#{Regexp.escape(normalized_name)}(?:\z|\s)/)
    return 0.9 if normalize(recent_product_name) == normalized_name && pronoun_reference?
    if meaningful_tokens.size == name_tokens.size && meaningful_tokens.size.positive? &&
        meaningful_tokens.zip(name_tokens).all? { |left, right| left.length >= 4 && DidYouMean::Levenshtein.distance(left, right) <= 1 }
      return 0.86
    end

    overlap = (meaningful_tokens & name_tokens).size
    coverage = name_tokens.empty? ? 0.0 : overlap.to_f / name_tokens.size
    precision = meaningful_tokens.empty? ? 0.0 : overlap.to_f / meaningful_tokens.size
    distance = DidYouMean::Levenshtein.distance(compact(query), compact(normalized_name))
    length = [ compact(query).length, compact(normalized_name).length ].max
    fuzzy = length.zero? ? 0.0 : [ 1.0 - (distance.to_f / length), 0.0 ].max
    [ (coverage * 0.58) + (precision * 0.27) + (fuzzy * 0.15), 1.0 ].min
  end

  def meaningful_tokens = @meaningful_tokens ||= tokens(query)
  def shared_single_token_candidates(ranked)
    return [] unless meaningful_tokens.one?

    token = meaningful_tokens.first
    ranked.select do |candidate|
      candidate.product.searchable_names.any? { |name| tokens(normalize(name)).include?(token) }
    end
  end
  def tokens(value) = value.split.reject { |token| token.in?(STOP_WORDS) }
  def pronoun_reference? = query.match?(/\b(this|that|it|eta|eita|oita|oi)\b|এটা|ওটা/)
  def normalize(value) = value.to_s.downcase.unicode_normalize(:nfkc).gsub(/(টা|টি)(?=\s|\z)/u, "").gsub(/[^\p{L}\p{N}]+/u, " ").squish
  def compact(value) = value.delete(" ")
end
