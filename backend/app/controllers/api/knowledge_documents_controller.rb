module Api
  class KnowledgeDocumentsController < BaseController
    before_action -> { require_roles!(:owner, :admin) }, only: %i[create update destroy sync reindex]
    before_action :set_document, only: %i[update destroy reindex]

    def index
      documents = current_business.knowledge_documents.order(active: :desc, source_type: :asc, title: :asc)
      render json: documents.map { |document| serialize(document) }
    end

    def create
      return if performed?

      document = current_business.knowledge_documents.new(manual_document_params.merge(source_type: "manual"))
      save_manual_document!(document)
      render json: serialize(document), status: :created
    rescue ActiveRecord::RecordInvalid => error
      render_validation_error(error)
    end

    def update
      return if performed?
      return render json: { error: "Only manual knowledge can be edited" }, status: :unprocessable_entity unless @document.source_type == "manual"

      @document.assign_attributes(manual_document_params)
      save_manual_document!(@document)
      render json: serialize(@document)
    rescue ActiveRecord::RecordInvalid => error
      render_validation_error(error)
    end

    def destroy
      return if performed?
      return render json: { error: "Generated knowledge must be updated at its source" }, status: :unprocessable_entity unless @document.source_type == "manual"

      @document.destroy!
      head :no_content
    end

    def status
      documents = current_business.knowledge_documents
      active = documents.active
      render json: {
        total: documents.count,
        active: active.count,
        inactive: documents.where(active: false).count,
        embedded: active.where.not(embedding: []).count,
        awaiting_embedding: active.where(embedding: []).count,
        embeddings_enabled: embeddings_enabled?,
        by_source: documents.group(:source_type).count,
        last_updated_at: documents.maximum(:updated_at)
      }
    end

    def preview
      query = params[:query].to_s.squish
      return render json: { error: "Query is required" }, status: :unprocessable_entity if query.blank?

      results = HybridBusinessKnowledgeRetriever.new(business: current_business, query: query, limit: 5).call
      render json: {
        query: query,
        results: results.map { |result| serialize_result(result) }
      }
    end

    def sync
      return if performed?

      SyncBusinessKnowledgeJob.perform_later(current_business.id)
      render json: { status: "queued" }, status: :accepted
    end

    def reindex
      return if performed?

      refresh_generated_document!(@document)
      if embeddings_enabled? && @document.reload.active?
        @document.update!(embedding: [], embedding_model: nil, embedded_at: nil)
        EmbedKnowledgeDocumentJob.perform_later(@document.id)
      end
      render json: serialize(@document.reload), status: :accepted
    end

    private

    def set_document
      @document = current_business.knowledge_documents.find(params[:id])
    end

    def manual_document_params
      params.expect(knowledge_document: [ :title, :content, :active, metadata: {} ])
    end

    def save_manual_document!(document)
      document.metadata ||= {}
      document.checksum = KnowledgeDocument.checksum_for(
        title: document.title, content: document.content, metadata: document.metadata
      )
      changed = document.new_record? || document.will_save_change_to_checksum? || document.will_save_change_to_active?
      document.embedding = [] if changed
      document.embedding_model = nil if changed
      document.embedded_at = nil if changed
      document.save!
      EmbedKnowledgeDocumentJob.perform_later(document.id) if changed && embeddings_enabled? && document.active?
    end

    def refresh_generated_document!(document)
      indexer = BusinessKnowledgeIndexer.new(business: current_business)
      case document.source_type
      when "product"
        indexer.sync_product(current_business.products.find(document.source_id))
      when "business_policy"
        indexer.sync_policy(current_business.business_policy)
      end
    end

    def serialize(document)
      document.as_json(only: %i[id source_type source_id title content metadata active embedding_model embedded_at created_at updated_at]).merge(
        "embedded" => document.embedding.present?,
        "editable" => document.source_type == "manual"
      )
    end

    def serialize_result(result)
      {
        score: result.score,
        lexical_rank: result.lexical_rank,
        semantic_rank: result.semantic_rank,
        citation: result.citation,
        content: result.document.content.truncate(600)
      }
    end

    def embeddings_enabled?
      ActiveModel::Type::Boolean.new.cast(ENV.fetch("KNOWLEDGE_EMBEDDINGS_ENABLED", "false"))
    end

    def render_validation_error(error)
      render json: { errors: error.record.errors.to_hash(true) }, status: :unprocessable_entity
    end
  end
end
