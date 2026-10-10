require "test_helper"

class KnowledgeDocumentTest < ActiveSupport::TestCase
  test "isolates source records by business" do
    first = Business.create!(name: "First Knowledge Shop", slug: "first-knowledge-shop")
    second = Business.create!(name: "Second Knowledge Shop", slug: "second-knowledge-shop")

    first.knowledge_documents.create!(attributes_for(source_id: 7))
    second.knowledge_documents.create!(attributes_for(source_id: 7))

    assert_equal 1, first.knowledge_documents.count
    assert_equal 1, second.knowledge_documents.count
  end

  test "prevents duplicate source records within a business" do
    business = Business.create!(name: "Knowledge Shop", slug: "knowledge-shop")
    business.knowledge_documents.create!(attributes_for(source_id: 9))

    duplicate = business.knowledge_documents.new(attributes_for(source_id: 9))
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:source_id], "has already been taken"
  end

  test "builds stable checksums from normalized metadata keys" do
    first = KnowledgeDocument.checksum_for(title: "Returns", content: "Seven days", metadata: { section: "policy" })
    second = KnowledgeDocument.checksum_for(title: "Returns", content: "Seven days", metadata: { "section" => "policy" })

    assert_equal first, second
  end

  private

  def attributes_for(source_id:)
    title = "Product guidance"
    content = "Suitable for office use"
    metadata = { category: "retail" }
    {
      source_type: "product", source_id: source_id, title: title, content: content, metadata: metadata,
      checksum: KnowledgeDocument.checksum_for(title: title, content: content, metadata: metadata)
    }
  end
end
