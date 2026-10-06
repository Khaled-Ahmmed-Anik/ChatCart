require "test_helper"

class KnowledgeDocumentEmbedderTest < ActiveSupport::TestCase
  FakeClient = Struct.new(:values, :model) do
    def embed(text:, task_type:)
      raise "missing content" if text.blank?
      raise "wrong task" unless task_type == "RETRIEVAL_DOCUMENT"

      values
    end
  end

  test "stores an embedding for an unchanged active document" do
    document = create_document
    client = FakeClient.new([ 0.2, 0.4, 0.8 ], "test-embedding")

    assert KnowledgeDocumentEmbedder.new(document: document, client: client).call

    document.reload
    assert_equal [ 0.2, 0.4, 0.8 ], document.embedding
    assert_equal "test-embedding", document.embedding_model
    assert document.embedded_at.present?
  end

  test "does not embed an inactive document" do
    document = create_document(active: false)

    assert_not KnowledgeDocumentEmbedder.new(
      document: document, client: FakeClient.new([ 1.0 ], "test-embedding")
    ).call
    assert_empty document.reload.embedding
  end

  private

  def create_document(active: true)
    business = Business.create!(name: "Embedding Shop", slug: "embedding-shop-#{SecureRandom.hex(3)}")
    title = "Product"
    content = "Useful product information"
    business.knowledge_documents.create!(source_type: "manual", title: title, content: content, active: active,
      checksum: KnowledgeDocument.checksum_for(title: title, content: content))
  end
end
