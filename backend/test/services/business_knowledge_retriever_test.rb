require "test_helper"

class BusinessKnowledgeRetrieverTest < ActiveSupport::TestCase
  test "returns ranked active knowledge only from the requested business" do
    first = create_business_with_product("First Retrieval Shop", "first-retrieval-shop", "Office Cotton Shirt",
      "Breathable formal clothing for office meetings")
    second = create_business_with_product("Second Retrieval Shop", "second-retrieval-shop", "Office Laptop",
      "Fast business laptop for office meetings")
    BusinessKnowledgeIndexer.new(business: first).sync!
    BusinessKnowledgeIndexer.new(business: second).sync!

    results = BusinessKnowledgeRetriever.new(business: first, query: "office meetings").call

    assert_equal [ "Office Cotton Shirt" ], results.map { |result| result.document.title }
    assert results.first.score.positive?
    assert_equal first.id, results.first.document.business_id
    assert_equal "product", results.first.citation[:source_type]
  end

  test "supports source filters and excludes inactive documents" do
    business = create_business_with_product("Filtered Shop", "filtered-retrieval-shop", "City Backpack",
      "Comfortable backpack for city travel")
    business.create_business_policy!(delivery_areas: "City delivery is available")
    BusinessKnowledgeIndexer.new(business: business).sync!
    business.knowledge_documents.find_by!(source_type: "product").update!(active: false)

    results = BusinessKnowledgeRetriever.new(
      business: business, query: "city delivery", source_types: [ "business_policy" ]
    ).call

    assert_equal 1, results.size
    assert_equal "business_policy", results.first.document.source_type
  end

  test "returns no results for a blank query" do
    business = Business.create!(name: "Blank Search Shop", slug: "blank-search-shop")

    assert_empty BusinessKnowledgeRetriever.new(business: business, query: "  ").call
  end

  private

  def create_business_with_product(name, slug, product_name, description)
    Business.create!(name: name, slug: slug).tap do |business|
      business.products.create!(name: product_name, price: 500, stock_quantity: 5, description: description)
    end
  end
end
