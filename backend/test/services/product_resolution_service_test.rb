require "test_helper"

class ProductResolutionServiceTest < ActiveSupport::TestCase
  setup do
    @business = Business.create!(name: "Resolver Shop", slug: "resolver-shop")
  end

  test "matches meaningful parts of multi-word names and configured aliases" do
    club = product("The Club", aliases: [ "TheClub", "ক্লাব" ])

    assert_equal club, resolve("club ta chai").product
    assert_equal club, resolve("TheClub 6ml den").product
    assert_equal club, resolve("ক্লাবটা আছে?").product
  end

  test "safely tolerates a one-character typo" do
    club = product("The Club")

    result = resolve("clab")

    assert result.matched?
    assert_equal club, result.product
  end

  test "asks for clarification when a partial name identifies multiple products" do
    product("The Club")
    product("Club Intense")

    result = resolve("club")

    assert result.ambiguous?
    assert_equal [ "Club Intense", "The Club" ], result.candidates.map { |candidate| candidate.product.name }.sort
  end

  test "uses recent context for a pronoun reference" do
    club = product("The Club")

    result = ProductResolutionService.new(
      business: @business, query: "eta 6ml den", recent_product_name: "The Club"
    ).resolve

    assert result.matched?
    assert_equal club, result.product
  end

  private

  def product(name, aliases: [])
    @business.products.create!(name: name, aliases: aliases, price: 500, stock_quantity: 10)
  end

  def resolve(query)
    ProductResolutionService.new(business: @business, query: query).resolve
  end
end
