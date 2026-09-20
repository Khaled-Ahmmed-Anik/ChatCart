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

  test "recommends every available option under a maximum budget up to the result limit" do
    result = recommend("500 takar moddhe ki ache?")

    assert result.budget_detected
    assert_equal [ "The Oud 3 ml", "The Oud 6 ml" ], result.offers.map(&:label)
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

  private

  def recommend(message)
    ProductRecommendationService.new(business: @business, message: message, limit: 10).call
  end
end
