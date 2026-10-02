class ConversationActionPlanner
  Plan = Data.define(:product, :variant, :quantity, :informational_outcomes, :ordering_cue) do
    def actionable?
      selections = [ product, variant, quantity ].count(&:present?)
      ordering_cue && selections >= 2
    end
  end

  INFORMATIONAL_PATTERNS = {
    delivery_charge_requested: /\b(delivery|shipping)\s*(charge|cost|fee|koto|kotho)|delivery charge|ডেলিভারি\s*(চার্জ|খরচ)/i,
    delivery_time_requested: /\b(delivery|shipping)\s*(time|when|kobe)|koto din|কত\s*দিন|কবে\s*(পাব|আসবে)/i,
    cash_on_delivery_requested: /\b(cod|cash on delivery|cash e|cash-e)\b|ক্যাশ\s*(অন\s*ডেলিভারি)?/i,
    payment_methods_requested: /\b(payment|pay)\s*(method|option|kivabe|how)|bkash|nagad|card/i,
    stock_inquiry: /\b(stock|available|availability|ache|ase)\b|স্টক|আছে/i,
    price_inquiry: /\b(price|dam|product cost)\b|দাম/i
  }.freeze

  ORDERING_CUE = /\b(want|need|take|give|send|order|buy|nibo|chai|den|dao|din|bottle|bottles|piece|pieces|ta|টা|নিব|চাই|দেন)\b/i

  def initialize(message:, business:, current_product: nil)
    @content = message.content.to_s
    @business = business
    @current_product = current_product
  end

  def call
    product = selected_product
    variant = selected_variant(product || current_product)
    Plan.new(
      product: product,
      variant: variant,
      quantity: selected_quantity,
      informational_outcomes: informational_outcomes,
      ordering_cue: ordering_cue?
    )
  end

  private

  attr_reader :content, :business, :current_product

  def selected_product
    normalized = content.downcase
    matches = business.products.available_for_sale.select do |product|
      product.searchable_names.any? { |name| normalized.include?(name.downcase) }
    end
    matches.reject! do |product|
      product.searchable_names.any? do |name|
        normalized.match?(/\b(?:not|no|na|bad|বাদ|না)\s+#{Regexp.escape(name.downcase)}\b/)
      end
    end
    matches.max_by { |product| product.searchable_names.map(&:length).max }
  end

  def selected_variant(product)
    return if product.blank? || product.available_variants.empty?

    product.available_variants.find do |variant|
      !variant_explicitly_rejected?(variant) && [ variant.name, variant.size ].compact.any? do |label|
        content.downcase.delete(" ").include?(label.downcase.delete(" "))
      end
    end
  end

  def variant_explicitly_rejected?(variant)
    [ variant.name, variant.size ].compact.any? do |label|
      pattern = Regexp.escape(label.downcase).gsub("\\ ", "\\s*")
      content.downcase.match?(/\b#{pattern}\b\s*(?:na|no|not|না)\b/)
    end
  end

  def selected_quantity
    normalized = content.downcase.tr("০১২৩৪৫৬৭৮৯", "0123456789")
      .gsub(/\b\d+(?:\.\d+)?\s*(?:ml|মিলি)\b/i, " ")
      .gsub(/\b01[3-9]\d{8}\b/, " ")
    word = Constants::Conversation::NUMBER_WORDS.find do |candidate, _number|
      normalized.match?(/\b#{Regexp.escape(candidate)}\b/)
    end
    return word.last if word.present?

    normalized[/\b\d+\b/]&.to_i&.then { |value| value if value.positive? }
  end

  def informational_outcomes
    INFORMATIONAL_PATTERNS.filter_map { |outcome, pattern| outcome if content.match?(pattern) }.uniq
  end

  def ordering_cue?
    content.match?(ORDERING_CUE) || selected_quantity.present?
  end
end
