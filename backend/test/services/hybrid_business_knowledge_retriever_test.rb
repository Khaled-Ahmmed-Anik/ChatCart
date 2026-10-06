require "test_helper"

class HybridBusinessKnowledgeRetrieverTest < ActiveSupport::TestCase
  FakeClient = Struct.new(:vector, :model) do
    def embed(text:, task_type:)
      raise "missing query" if text.blank?
      raise "wrong task" unless task_type == "RETRIEVAL_QUERY"

      vector
    end
  end

  test "combines lexical and semantic ranks inside one tenant" do
    business = Business.create!(name: "Hybrid Shop", slug: "hybrid-shop")
    semantic = create_document(business, "Formal Choice", "Professional clothing", [ 1.0, 0.0 ])
    lexical = create_document(business, "Office Shirt", "Office shirt for meetings", [ 0.0, 1.0 ])
    other = Business.create!(name: "Other Hybrid Shop", slug: "other-hybrid-shop")
    create_document(other, "Leaked Result", "Office secret", [ 1.0, 0.0 ])

    results = HybridBusinessKnowledgeRetriever.new(
      business: business, query: "office", embedding_client: FakeClient.new([ 1.0, 0.0 ], "test"),
      semantic_enabled: true
    ).call

    assert_equal [ semantic.id, lexical.id ].sort, results.map { |result| result.document.id }.sort
    assert_not_includes results.map { |result| result.document.title }, "Leaked Result"
    assert results.any? { |result| result.semantic_rank.present? }
    assert results.any? { |result| result.lexical_rank.present? }
  end

  test "falls back to lexical retrieval when semantic embedding fails" do
    business = Business.create!(name: "Fallback Shop", slug: "hybrid-fallback-shop")
    create_document(business, "Delivery Policy", "Delivery takes two days", [ 0.5, 0.5 ])
    client = Object.new
    client.define_singleton_method(:embed) { |**| raise KeyError, "temporary failure" }

    results = HybridBusinessKnowledgeRetriever.new(
      business: business, query: "delivery", embedding_client: client, semantic_enabled: true
    ).call

    assert_equal [ "Delivery Policy" ], results.map { |result| result.document.title }
    assert_nil results.first.semantic_rank
  end

  private

  def create_document(business, title, content, embedding)
    business.knowledge_documents.create!(source_type: "manual", title: title, content: content,
      checksum: KnowledgeDocument.checksum_for(title: title, content: content), embedding: embedding,
      embedding_model: "test", embedded_at: Time.current)
  end
end
