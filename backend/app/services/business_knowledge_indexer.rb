class BusinessKnowledgeIndexer
  POLICY_FIELDS = %w[
    delivery_areas delivery_charges delivery_time payment_methods cash_on_delivery return_policy
    discount_policy bulk_order_policy trial_policy authenticity_statement trust_information additional_information
  ].freeze

  def initialize(business:)
    @business = business
  end

  def sync!
    business.products.find_each { |product| sync_product(product) }
    sync_policy(business.business_policy) if business.business_policy
    deactivate_missing_products!
  end

  def sync_product(product)
    metadata = {
      category: product.category, tags: product.tags, price: product.starting_price.to_s,
      in_stock: product.total_available_stock.positive?, active: product.active? && !product.archived?
    }.compact
    content = [
      product.short_description, product.description, product.benefits, product.suitable_for,
      product.usage_instructions, product.searchable_names.drop(1).presence&.then { |aliases| "Aliases: #{aliases.join(', ')}" }
    ].compact_blank.join("\n")
    content = "Catalog product: #{product.name}" if content.blank?

    persist(source_type: "product", source_id: product.id, title: product.name, content: content,
      metadata: metadata, active: product.active? && !product.archived?)
  end

  def sync_policy(policy)
    sections = POLICY_FIELDS.filter_map do |field|
      value = policy.public_send(field).presence
      "#{field.humanize}: #{value}" if value
    end
    return if sections.empty?

    persist(source_type: "business_policy", source_id: policy.id, title: "#{business.name} policies",
      content: sections.join("\n"), metadata: { sections: POLICY_FIELDS }, active: true)
  end

  private

  attr_reader :business

  def persist(source_type:, source_id:, title:, content:, metadata:, active:)
    document = business.knowledge_documents.find_or_initialize_by(source_type: source_type, source_id: source_id)
    checksum = KnowledgeDocument.checksum_for(title: title, content: content, metadata: metadata)
    return document if document.persisted? && document.checksum == checksum && document.active == active

    document.update!(title: title, content: content, metadata: metadata, checksum: checksum, active: active,
      embedding: [], embedding_model: nil, embedded_at: nil)
    EmbedKnowledgeDocumentJob.perform_later(document.id) if embeddings_enabled? && active
    document
  end

  def embeddings_enabled?
    ActiveModel::Type::Boolean.new.cast(ENV.fetch("KNOWLEDGE_EMBEDDINGS_ENABLED", "false"))
  end

  def deactivate_missing_products!
    current_ids = business.products.select(:id)
    business.knowledge_documents.where(source_type: "product").where.not(source_id: current_ids).update_all(active: false)
  end
end
