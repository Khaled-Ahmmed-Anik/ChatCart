require "test_helper"

class CatalogueRecommendationsTest < ActiveSupport::TestCase
  setup do
    @business = Business.create!(name: "Clothing Shop", slug: "catalogue-clothing", category: "clothing")
    @cotton = @business.products.create!(name: "Everyday Shirt", price: 600, stock_quantity: 10,
      product_attributes: { material: "cotton", color: [ "blue", "white" ], purpose: "office" })
    @silk = @business.products.create!(name: "Formal Shirt", price: 900, stock_quantity: 10,
      product_attributes: { material: "silk", color: [ "black" ], purpose: "wedding" })
  end

  test "extracts catalogue attributes and remembers corrections" do
    extractor = CataloguePreferenceExtractor.new("blue cotton chai", business: @business)
    first = extractor.call
    assert_equal [ "cotton" ], first.dig("attributes", "material")
    assert_equal [ "blue" ], first.dig("attributes", "color")
    corrected = CataloguePreferenceExtractor.new("blue na white chai", business: @business).call(existing: first)
    assert_equal [ "white" ], corrected.dig("attributes", "color")
    assert_equal [ "blue" ], corrected.dig("excluded_attributes", "color")
  end

  test "asks about real catalogue attributes instead of fragrances" do
    result = ProductRecommendationService.new(business: @business, message: "suggest something").call
    assert_match(/material|color|purpose/, result.clarification_question)
    assert_no_match(/perfume|scent|oud/, result.clarification_question)
  end

  test "ranks attribute matches within the stated budget" do
    preferences = CataloguePreferenceExtractor.new("cotton under 800", business: @business).call
    result = ProductRecommendationService.new(business: @business, message: "cotton under 800", preferences: preferences).call
    assert_equal @cotton, result.offers.first.product
    assert_nil result.clarification_question
    assert result.offers.all? { |offer| offer.price <= 800 }
  end

  test "excludes rejected materials" do
    preferences = CataloguePreferenceExtractor.new("no silk", business: @business).call
    result = ProductRecommendationService.new(business: @business, message: "under 1000", preferences: preferences).call
    assert_equal [ @cotton ], result.offers.map(&:product)
  end

  test "preserves perfume-specific discovery for fragrance businesses" do
    @business.update!(category: "perfume")
    preferences = CataloguePreferenceExtractor.new("fresh woody combo", business: @business).call
    assert_equal "combo", preferences["format"]
    assert_equal %w[fresh woody], preferences["scent_families"]
  end

  test "food discovery uses dietary catalogue facts without leaking clothing products" do
    food = Business.create!(name: "Food Shop", slug: "catalogue-food", category: "food")
    meal = food.products.create!(name: "Lunch Box", price: 250, stock_quantity: 20,
      product_attributes: { diet: "vegetarian", spice: "mild" })
    result = ProductRecommendationService.new(business: food, message: "vegetarian under 300").call
    assert_equal [ meal ], result.offers.map(&:product)
    assert_nil result.clarification_question
  end

  test "electronics discovery ranks the customer's intended purpose" do
    electronics = Business.create!(name: "Tech Shop", slug: "catalogue-tech", category: "electronics")
    gaming = electronics.products.create!(name: "Gaming Mouse", price: 900, stock_quantity: 5,
      product_attributes: { purpose: "gaming" })
    electronics.products.create!(name: "Office Mouse", price: 500, stock_quantity: 5,
      product_attributes: { purpose: "office" })
    result = ProductRecommendationService.new(business: electronics, message: "gaming under 1000").call
    assert_equal gaming, result.offers.first.product
    assert_nil result.clarification_question
  end
end
