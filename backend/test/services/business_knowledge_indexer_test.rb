require "test_helper"

class BusinessKnowledgeIndexerTest < ActiveSupport::TestCase
  test "indexes rich products and policies inside the business" do
    business = Business.create!(name: "Indexed Shop", slug: "indexed-shop")
    product = business.products.create!(name: "Office Shirt", price: 1250, stock_quantity: 4,
      description: "Breathable cotton shirt", suitable_for: "Office and smart casual use", aliases: [ "formal shirt" ])
    business.create_business_policy!(delivery_time: "Two days in Dhaka", return_policy: "Return within seven days")

    assert_difference "business.knowledge_documents.count", 2 do
      BusinessKnowledgeIndexer.new(business: business).sync!
    end

    product_document = business.knowledge_documents.find_by!(source_type: "product", source_id: product.id)
    assert_includes product_document.content, "Office and smart casual"
    assert_includes product_document.content, "formal shirt"
    assert_equal "1250.0", product_document.metadata["price"]
    assert business.knowledge_documents.exists?(source_type: "business_policy")
  end

  test "updates changed knowledge without creating duplicates" do
    business = Business.create!(name: "Updated Shop", slug: "updated-shop")
    product = business.products.create!(name: "Travel Bag", price: 900, stock_quantity: 2, description: "Small bag")
    indexer = BusinessKnowledgeIndexer.new(business: business)
    indexer.sync!
    original_checksum = business.knowledge_documents.find_by!(source_type: "product").checksum

    product.update!(description: "Water-resistant travel bag")
    assert_no_difference "business.knowledge_documents.count" do
      indexer.sync!
    end

    document = business.knowledge_documents.find_by!(source_type: "product")
    assert_not_equal original_checksum, document.checksum
    assert_includes document.content, "Water-resistant"
  end

  test "marks archived products inactive" do
    business = Business.create!(name: "Archive Shop", slug: "archive-knowledge-shop")
    product = business.products.create!(name: "Old Product", price: 100, stock_quantity: 1)
    indexer = BusinessKnowledgeIndexer.new(business: business)
    indexer.sync!

    product.archive!
    indexer.sync_product(product)

    assert_not business.knowledge_documents.find_by!(source_type: "product").active?
  end
end
