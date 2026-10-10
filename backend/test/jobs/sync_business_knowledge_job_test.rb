require "test_helper"

class SyncBusinessKnowledgeJobTest < ActiveJob::TestCase
  test "indexes the requested business sources" do
    business = Business.create!(name: "Alpha", slug: "alpha-sync-job", category: "retail")
    product = business.products.create!(name: "The Club", price: 390, stock_quantity: 3)

    SyncBusinessKnowledgeJob.perform_now(business.id)

    document = business.knowledge_documents.find_by!(source_type: "product", source_id: product.id)
    assert_equal "The Club", document.title
  end
end
