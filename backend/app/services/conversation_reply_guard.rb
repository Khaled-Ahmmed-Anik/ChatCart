class ConversationReplyGuard
  MAX_REPLY_LENGTH = 1_200
  RISKY_CLAIMS = %w[free guaranteed guarantee discount original authentic refund return delivery].freeze

  def initialize(candidate:, fallback:, pending_order:, response_plan: nil, tool_evidence: [], recent_replies: [])
    @candidate = candidate.to_s.strip
    @fallback = fallback.to_s
    @pending_order = pending_order
    @response_plan = response_plan
    @tool_evidence = tool_evidence
    @recent_replies = recent_replies
  end

  def valid?
    candidate.present? &&
      candidate.length <= MAX_REPLY_LENGTH &&
      preserves_required_facts? &&
      uses_only_approved_prices? &&
      uses_only_approved_products? &&
      uses_only_approved_claims? &&
      preserves_required_question? &&
      not_a_recent_duplicate?
  end

  private

  attr_reader :candidate, :fallback, :pending_order, :response_plan, :tool_evidence, :recent_replies

  def approved_text
    @approved_text ||= [ fallback, response_plan&.facts.to_h.to_json, tool_evidence.to_json ].compact.join(" ")
  end

  def preserves_required_facts?
    protected_facts.all? { |fact| candidate.include?(fact) }
  end

  def protected_facts
    order_facts = [
      pending_order.product&.name,
      pending_order.quantity&.to_s,
      pending_order.customer_name,
      pending_order.phone,
      pending_order.address,
      formatted_total
    ].compact
    catalog_facts = pending_order.conversation.business.products.find_each.flat_map do |product|
      variant_facts = product.product_variants.flat_map do |variant|
        [ variant.display_name, formatted_price(variant.price) ]
      end
      [ product.name, formatted_price(product.price), *variant_facts ]
    end

    (order_facts + catalog_facts).uniq.select { |fact| fallback.include?(fact) }
  end

  def uses_only_approved_prices?
    monetary_values(candidate).all? { |value| approved_monetary_values.include?(value) }
  end

  def approved_monetary_values
    values = monetary_values(approved_text)
    collect_price_values(tool_evidence, values)
    values.uniq
  end

  def collect_price_values(value, values, key = nil)
    case value
    when Hash
      value.each { |nested_key, nested_value| collect_price_values(nested_value, values, nested_key.to_s) }
    when Array
      value.each { |nested_value| collect_price_values(nested_value, values, key) }
    else
      values << value.to_d if key.to_s.include?("price") && value.to_s.match?(/\A\d+(?:\.\d+)?\z/)
    end
  end

  def monetary_values(text)
    text.to_s.scan(/(?:৳|tk\.?|taka\s*)\s*([0-9]+(?:\.[0-9]+)?)/i).flatten.map { |value| value.to_d }
  end

  def uses_only_approved_products?
    pending_order.conversation.business.products.find_each.all? do |product|
      !candidate.downcase.include?(product.name.downcase) || approved_text.downcase.include?(product.name.downcase)
    end
  end

  def uses_only_approved_claims?
    RISKY_CLAIMS.all? do |claim|
      !candidate.downcase.match?(/\b#{Regexp.escape(claim)}\b/) || approved_text.downcase.match?(/\b#{Regexp.escape(claim)}\b/)
    end
  end

  def preserves_required_question?
    return true if response_plan&.pending_question.blank?
    return true unless fallback.include?("?")

    candidate.include?("?")
  end

  def not_a_recent_duplicate?
    normalized = normalize(candidate)
    Array(recent_replies).none? { |reply| normalize(reply) == normalized }
  end

  def normalize(text)
    text.to_s.downcase.gsub(/[^\p{L}\p{N}]+/u, " ").squish
  end

  def formatted_total
    return if pending_order.product.blank? || pending_order.quantity.blank?

    formatted_price(pending_order.total_price)
  end

  def formatted_price(value)
    amount = value.to_d
    amount = amount.to_i if amount.frac.zero?
    "৳#{amount}"
  end
end
