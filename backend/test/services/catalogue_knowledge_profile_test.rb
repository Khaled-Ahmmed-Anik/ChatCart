require "test_helper"

class CatalogueKnowledgeProfileTest < ActiveSupport::TestCase
  setup do
    @business = Business.create!(name: "Profiles", slug: "catalogue-profiles", category: "electronics")
    @product = @business.products.create!(name: "Cotton Shirt", category: "clothing", price: 500, stock_quantity: 10)
  end

  test "product category overrides the business default without inventing facts" do
    status = CatalogueKnowledgeProfile.new(@product).status
    assert_equal "apparel", status[:profile]
    assert_equal %w[material care], status[:missing_topics]
    assert_includes status[:missing_fields], "description"
    assert_equal false, status[:independently_verified]
    assert_empty status[:available_topics]
  end

  test "seller supplied facts answer relevant questions and supersede stale descriptions" do
    @product.update!(description: "Material: polyester.", product_attributes: {
      catalogue_facts: { material: "Material: 100% cotton.", care: "Cold wash only. Do not tumble dry." }
    })
    answer = CatalogueQuestionAnswerer.new(product: @product, text: "What material and how to wash?").content
    assert_includes answer, "100% cotton"
    assert_includes answer, "Do not tumble dry"
    assert_not_includes answer, "polyester"
    assert_empty CatalogueKnowledgeProfile.new(@product).status[:missing_topics]
  end

  test "invalid or oversized structured facts do not become evidence" do
    @product.update!(product_attributes: { catalogue_facts: {
      material: { claim: "silk" }, care: "x" * (Constants::Catalogue::MAXIMUM_FACT_LENGTH + 1), unknown_topic: "promise"
    } })
    assert_empty CatalogueKnowledgeProfile.new(@product).facts
    answer = CatalogueQuestionAnswerer.new(product: @product, text: "Material?").content
    assert_includes answer, "not verified"
    assert_not_includes answer, "silk"
  end

  test "structured fragrance facts work through the existing reply generator" do
    @business.update!(category: "perfume")
    @product.update!(name: "Evening Oud", category: "fragrance", product_attributes: {
      longevity_hours: "12", catalogue_facts: { longevity: "Lasts around 4 hours; depends on use." }
    })
    conversation = @business.conversations.create!(channel: "facebook", external_customer_id: "profile-fragrance")
    order = conversation.create_pending_order!(product: @product)
    message = conversation.messages.create!(sender_type: :customer, content: "What is the longevity?")
    answer = BotReplyGenerator.new(pending_order: order, customer_message: message, outcome: :product_details_requested).content
    assert_includes answer, "4 hours"
    assert_not_includes answer, "12 hours"
  end

  test "food fragrance and general profiles remain distinct" do
    { "bakery" => [ "food", %w[ingredients allergens] ], "perfume" => [ "fragrance", %w[scent longevity] ],
      "retail" => [ "general", [] ] }.each do |category, (profile, topics)|
      @business.update!(category: category)
      @product.update!(category: category)
      status = CatalogueKnowledgeProfile.new(@product).status
      assert_equal profile, status[:profile]
      assert_equal topics, status[:missing_topics]
    end
  end
end
