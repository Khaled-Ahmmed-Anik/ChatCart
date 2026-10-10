class KnowledgeDocumentEmbedder
  def initialize(document:, client: KnowledgeEmbeddingClient.new)
    @document = document
    @client = client
  end

  def call
    return false unless document.active?

    checksum = document.checksum
    values = client.embed(text: "#{document.title}\n#{document.content}", task_type: "RETRIEVAL_DOCUMENT")
    updated = KnowledgeDocument.where(id: document.id, checksum: checksum, active: true).update_all(
      embedding: values, embedding_model: client.model, embedded_at: Time.current, updated_at: Time.current
    )
    updated == 1
  end

  private

  attr_reader :document, :client
end
