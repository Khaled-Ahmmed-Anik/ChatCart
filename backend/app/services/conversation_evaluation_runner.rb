class ConversationEvaluationRunner
  MINIMUM_ACCURACY = 0.70
  MINIMUM_COVERAGE = 0.80

  Message = Data.define(:content)

  def initialize(cases: ConversationEvaluationSuite.load)
    @cases = cases
  end

  def call
    results = cases.map { |evaluation_case| evaluate(evaluation_case) }
    {
      total: results.size,
      correct: results.count { |result| result[:correct] },
      covered: results.count { |result| result[:actual_intent].present? },
      accuracy: ratio(results.count { |result| result[:correct] }, results.size),
      coverage: ratio(results.count { |result| result[:actual_intent].present? }, results.size),
      passing: passing?(results),
      by_locale: grouped_metrics(results, :locale),
      by_tag: grouped_metrics(results.flat_map { |result| result[:tags].map { |tag| result.merge(tag: tag) } }, :tag),
      failures: results.reject { |result| result[:correct] }
    }
  end

  private

  attr_reader :cases

  def evaluate(evaluation_case)
    order = PendingOrder.new(status: evaluation_case.pending_order_status)
    result = CompactIntentClassifier.new(
      message: Message.new(content: evaluation_case.message), pending_order: order
    ).classify
    actual_intent = result.interpretation&.intent

    {
      id: evaluation_case.id,
      message: evaluation_case.message,
      locale: evaluation_case.locale,
      tags: evaluation_case.tags,
      expected_intent: evaluation_case.expected_intent,
      actual_intent: actual_intent,
      score: result.score.round(4),
      runner_up_score: result.runner_up_score.round(4),
      correct: actual_intent == evaluation_case.expected_intent
    }
  end

  def passing?(results)
    accuracy = ratio(results.count { |result| result[:correct] }, results.size)
    coverage = ratio(results.count { |result| result[:actual_intent].present? }, results.size)
    accuracy >= MINIMUM_ACCURACY && coverage >= MINIMUM_COVERAGE
  end

  def grouped_metrics(results, key)
    results.group_by { |result| result.fetch(key) }.transform_values do |entries|
      {
        total: entries.size,
        accuracy: ratio(entries.count { |entry| entry[:correct] }, entries.size),
        coverage: ratio(entries.count { |entry| entry[:actual_intent].present? }, entries.size)
      }
    end
  end

  def ratio(numerator, denominator)
    return 0.0 if denominator.zero?

    (numerator.fdiv(denominator)).round(4)
  end
end
