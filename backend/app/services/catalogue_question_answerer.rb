class CatalogueQuestionAnswerer
  def initialize(product:, text:, language: "english")
    @product = product
    @text = text.to_s
    @locale = language.to_s.in?(%w[banglish bn]) ? language.to_s : "en"
  end

  def content
    return if product.blank? || topics.empty?

    seen_evidence = Set.new
    answers = topics.map do |topic, definition|
      declared_fact = declared_facts[topic.to_s]
      evidence = declared_fact.present? ? [ declared_fact ] : evidence_lines.select { |line| line.match?(definition.fetch(:evidence)) }
      if topic == :cable && declared_fact.blank?
        evidence = evidence.select { |line| line.match?(Constants::Catalogue::INCLUSION_EVIDENCE) }
      end
      if topic == :designs
        evidence = product.available_variants.map do |variant|
          translation("available_variant", name: variant.display_name,
            price: ActiveSupport::NumberHelper.number_to_delimited(variant.price), count: variant.stock_quantity)
        end
      end
      if evidence.empty? || evidence.all? { |line| line.match?(Constants::Catalogue::UNVERIFIED_EVIDENCE) }
        translation("unknown", topic: translation("topics.#{topic}"))
      else
        evidence_reply(evidence, seen_evidence)
      end
    end
    if topics.key?(:compatibility)
      answers << translation("compatibility_check")
    end
    [ translation("intro", product: product.name, price: formatted_price), *answers.compact.uniq ].join("\n\n")
  end

  private

  attr_reader :product, :text, :locale

  def evidence_reply(evidence, seen_evidence)
    selected = evidence.sort_by { |line| line.match?(/\b(?:not|cannot|require|confirm|depend|one .*time)\b/i) ? 0 : 1 }
      .reject { |line| seen_evidence.include?(line) }.first(Constants::Catalogue::MAXIMUM_EVIDENCE_LINES)
    seen_evidence.merge(selected)
    selected.map { |line| "• #{line}" }.join("\n").presence
  end

  def declared_facts
    @declared_facts ||= CatalogueKnowledgeProfile.new(product).facts
  end

  def topics
    @topics ||= Constants::Catalogue::QUESTION_TOPICS.select { |_topic, definition| text.match?(definition.fetch(:question)) }.tap do |selected|
      selected.delete(:package) if selected.key?(:cable) && !text.match?(/\b(?:package|box|contents|else)\b/i)
      selected.delete(:package) if ConversationActionPlanner.policy_information_outcomes(text).include?(:delivery_charge_requested)
    end
  end

  def evidence_lines
    @evidence_lines ||= [ product.description, product.usage_instructions ].compact.join("\n").split(/\n|(?<=[.!?])\s+/)
      .reject { |line| line.strip.start_with?("#") }
      .map { |line| line.gsub(/\*\*|^\s*[-•]\s*/, "").strip }.reject(&:blank?).uniq
  end

  def formatted_price
    price = product.starting_price
    "৳#{price.frac.zero? ? price.to_i : price}"
  end

  def translation(key, **values)
    I18n.t("catalogue_answers.#{locale}.#{key}", **values, locale: :en)
  end
end
