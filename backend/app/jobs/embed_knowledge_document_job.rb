class EmbedKnowledgeDocumentJob < ApplicationJob
  queue_as :default

  retry_on KeyError, Net::OpenTimeout, Net::ReadTimeout, Timeout::Error, wait: :polynomially_longer, attempts: 3
  discard_on ActiveRecord::RecordNotFound

  def perform(knowledge_document_id)
    KnowledgeDocumentEmbedder.new(document: KnowledgeDocument.find(knowledge_document_id)).call
  end
end
