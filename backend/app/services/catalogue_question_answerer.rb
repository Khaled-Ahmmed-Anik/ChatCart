class CatalogueQuestionAnswerer
  def initialize(product:, text:, language: "english")
    @product = product
    @text = text.to_s
    @locale = language.to_s.in?(%w[banglish bn]) ? language.to_s : "en"
  end

  def content
    return if product.blank? || topics.empty?

    answers = topics.map do |topic, definition|
      declared_fact = declared_facts[topic.to_s]
      evidence = declared_fact.present? ? [ declared_fact ] : evidence_lines.select { |line| line.match?(definition.fetch(:evidence)) }
      if topic == :designs
        evidence = product.available_variants.map do |variant|
          translation("available_variant", name: variant.display_name,
            price: ActiveSupport::NumberHelper.number_to_delimited(variant.price), count: variant.stock_quantity)
        end
      end
      if evidence.empty? || topic == :cable && evidence.all? { |line| line.match?(/confirm|check|verify/i) }
        translation("unknown", topic: translation("topics.#{topic}"))
      else
        evidence.sort_by { |line| line.match?(/\b(?:not|cannot|require|confirm|depend|one .*time)\b/i) ? 0 : 1 }
          .first(Constants::Catalogue::MAXIMUM_EVIDENCE_LINES).map { |line| "• #{line}" }.join("\n")
      end
    end
    if topics.key?(:compatibility)
      answers << translation("compatibility_check")
    end
    [ translation("intro", product: product.name, price: formatted_price), *answers.uniq ].join("\n\n")
  end

  private

  attr_reader :product, :text, :locale

  def declared_facts
    @declared_facts ||= CatalogueKnowledgeProfile.new(product).facts
  end

  def topics
    @topics ||= Constants::Catalogue::QUESTION_TOPICS.select { |_topic, definition| text.match?(definition.fetch(:question)) }
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
