require "test_helper"

class ProductRecommendationServiceTest < ActiveSupport::TestCase
  setup do
    @business = Business.create!(name: "Recommendation Shop", slug: "recommendation-shop")
    oud = @business.products.create!(
      name: "The Oud", price: 250, stock_quantity: 0, category: "fragrance",
      tags: "oud woody premium", suitable_for: "evening and special occasions"
    )
    oud.product_variants.create!(name: "3 ml", size: "3 ml", price: 250, stock_quantity: 10)
    oud.product_variants.create!(name: "6 ml", size: "6 ml", price: 450, stock_quantity: 8)
    oud.product_variants.create!(name: "12 ml", size: "12 ml", price: 800, stock_quantity: 5)
    fresh = @business.products.create!(name: "Fresh Musk", price: 600, stock_quantity: 10, tags: "fresh daily")
    @business.products.create!(name: "Unavailable", price: 100, stock_quantity: 0)
    assert fresh.persisted?
  end

  test "recommends the largest affordable variant for each product under a maximum budget" do
    result = recommend("500 takar moddhe ki ache?")

    assert result.budget_detected
    assert_equal [ "The Oud 6 ml" ], result.offers.map(&:label)
    assert result.offers.all? { |offer| offer.price <= 500 }
  end

  test "supports a Bangla-digit price range" do
    result = recommend("৪০০ থেকে ৭০০ টাকার মধ্যে suggest koren")

    assert_equal [ "Fresh Musk", "The Oud 6 ml" ], result.offers.map(&:label)
    assert result.offers.all? { |offer| offer.price.between?(400, 700) }
  end

  test "returns the catalog floor when no product matches" do
    result = recommend("200 takar under kichu ache?")

    assert_empty result.offers
    assert_equal 250.to_d, result.minimum_price
  end

  test "asks whether the customer wants a single fragrance or combo for a broad request" do
    result = ProductRecommendationService.new(
      business: @business,
      message: "suggest something"
    ).call

    assert_includes result.clarification_question, "one perfume or a combo"
  end

  test "filters recommendations using a remembered product format" do
    combo = @business.products.create!(
      name: "Fresh Set", price: 900, stock_quantity: 5, product_type: "fixed_combo",
      category: "combo", tags: "fresh office"
    )

    result = ProductRecommendationService.new(
      business: @business,
      message: "fresh office fragrance",
      preferences: { format: "combo", scent_families: [ "fresh" ], occasions: [ "office" ] },
      limit: 10
    ).call

    assert_equal [ combo ], result.offers.map(&:product).uniq
    assert_nil result.clarification_question
  end

  test "recommends immediately when scent and occasion preferences are already useful" do
    result = ProductRecommendationService.new(
      business: @business,
      message: "fresh for daily use",
      preferences: { scent_families: [ "fresh" ], occasions: [ "daily" ] }
    ).call

    assert_nil result.clarification_question
    assert_equal "Fresh Musk", result.offers.first.product.name
  end

  test "excludes rejected products and unwanted scent families" do
    sweet = @business.products.create!(name: "Sweet One", price: 400, stock_quantity: 10, tags: "sweet fruity")
    fresh = @business.products.find_by!(name: "Fresh Musk")

    result = ProductRecommendationService.new(
      business: @business,
      message: "show something else",
      preferences: { avoid_scent_families: [ "sweet" ], rejected_product_ids: [ fresh.id ] },
      limit: 10
    ).call

    assert_not_includes result.offers.map(&:product), sweet
    assert_not_includes result.offers.map(&:product), fresh
  end

  private

  def recommend(message)
    ProductRecommendationService.new(business: @business, message: message, limit: 10).call
  end
end
