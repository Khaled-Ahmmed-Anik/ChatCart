require "test_helper"

class CatalogueCategoryDiscoveryTest < ActiveSupport::TestCase
  setup do
    @business = Business.create!(name: "Device Shop", slug: "category-device-shop", category: "electronics")
    @charger = @business.products.create!(name: "Anker Nano 45W", category: "charger", price: 1849, stock_quantity: 10)
    @earbuds = @business.products.create!(name: "Wireless Buds", category: "earbuds", price: 599, stock_quantity: 10)
    @conversation = @business.conversations.create!(channel: "facebook", external_customer_id: "category-test")
    @order = @conversation.create_pending_order!(status: :collecting_product)
  end

  test "production charger sequence filters category and repairs contextual typo" do
    [ "need charger", "cgarger", "kono charger ase?" ].each do |text|
      message = @conversation.messages.create!(sender_type: :customer, content: text)
      processor = ConversationMessageProcessor.new(message: message, pending_order: @order.reload)
      processor.process
      assert_equal :product_recommendation_requested, processor.outcome, text
      reply = BotReplyGenerator.new(pending_order: @order, customer_message: message, outcome: processor.outcome).content
      assert_includes reply, @charger.name
      refute_includes reply, @earbuds.name
      assert_nil @order.reload.product_id
      assert_includes reply, "Ji," if text.include?("ase")
    end
  end

  test "typo recovery requires context and never crosses tenants" do
    assert_empty CatalogueCategoryResolver.call(business: @business, text: "cgarger")
    assert_equal [ "charger" ], CatalogueCategoryResolver.call(business: @business, text: "cgarger", previous_categories: [ "charger" ])
    other = Business.create!(name: "Other", slug: "other-category", category: "electronics")
    other.products.create!(name: "Tablet", category: "tablet", price: 5000, stock_quantity: 3)
    assert_empty CatalogueCategoryResolver.call(business: @business, text: "need tablet")
  end

  test "new category replaces old category and budget alternatives remain within it" do
    preferences = CataloguePreferenceExtractor.new("need earbuds", business: @business).call(existing: { "categories" => [ "charger" ] })
    assert_equal [ "earbuds" ], preferences["categories"]
    result = ProductRecommendationService.new(business: @business, message: "charger under 500").call
    assert_equal [ @charger ], result.offers.map(&:product)
    refute result.exact_match
  end

  test "inactive and out of stock products are never offered" do
    @charger.update!(stock_quantity: 0)
    result = ProductRecommendationService.new(business: @business, message: "need charger").call
    assert_empty result.offers
    @charger.update!(stock_quantity: 10, active: false)
    assert_empty CatalogueCategoryResolver.call(business: @business, text: "need charger")
  end

  test "category browsing preserves a paused checkout and labels budget alternatives" do
    @order.update!(product: @earbuds, quantity: 2, status: :collecting_name)
    message = @conversation.messages.create!(sender_type: :customer, content: "need charger under 500")
    processor = ConversationMessageProcessor.new(message: message, pending_order: @order)
    processor.process
    assert_equal :product_recommendation_requested, processor.outcome
    assert_predicate @order.reload, :collecting_product?
    reply = BotReplyGenerator.new(pending_order: @order, customer_message: message, outcome: processor.outcome).content
    assert_includes reply, "outside your requested range"
    assert_includes reply, @charger.name
    assert_equal @earbuds.id, @conversation.reload.conversation_state.dig("guided_sales", "context", "suspended_order", "product_id")
  end

  test "plural category nouns and specific accessory categories resolve" do
    assert_equal [ "charger" ], CatalogueCategoryResolver.call(business: @business, text: "chargers ase?")
    @business.products.create!(name: "Earbuds Case", category: "earbuds accessories", price: 299, stock_quantity: 1)
    assert_equal [ "earbuds accessories" ], CatalogueCategoryResolver.call(business: @business, text: "need earbuds accessories")
  end
end
