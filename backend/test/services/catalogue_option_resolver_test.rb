require "test_helper"

class CatalogueOptionResolverTest < ActiveSupport::TestCase
  test "compact volume labels match without matching size letters inside words" do
    product = Product.create!(name: "Oil", price: 350, stock_quantity: 10)
    small = product.product_variants.create!(name: "10 ML", size: "10 ML", price: 350, stock_quantity: 10)
    product.product_variants.create!(name: "30 ML", size: "30 ML", price: 850, stock_quantity: 10)
    assert_equal small, CatalogueOptionResolver.call(product: product, text: "10ml price koto?")
    small.update!(name: "M", size: "M")
    assert_nil CatalogueOptionResolver.call(product: product, text: "dam koto?")
  end

  test "resolves clothing sizes and singular cable lengths" do
    product = Product.create!(name: "Shirt", price: 600, stock_quantity: 10)
    medium = product.product_variants.create!(name: "M", size: "M", price: 600, stock_quantity: 10)
    assert_equal medium, CatalogueOptionResolver.call(product: product, text: "Medium den")
    medium.update!(name: "2 metres", size: "2 metres")
    assert_equal medium, CatalogueOptionResolver.call(product: product, text: "2 metre den")
  end

  test "configured aliases are product scoped and ambiguous answers are refused" do
    product = Product.create!(name: "Bag", price: 450, stock_quantity: 10,
      product_attributes: { option_aliases: { "Regular" => [ "daily" ] } })
    regular = product.product_variants.create!(name: "Regular", price: 450, stock_quantity: 10)
    assert_equal regular, CatalogueOptionResolver.call(product: product, text: "daily")
    assert_nil CatalogueOptionResolver.call(product: product, text: "daily na")
    product.product_variants.create!(name: "Daily", price: 600, stock_quantity: 10)
    assert_nil CatalogueOptionResolver.call(product: product, text: "daily")
  end
end
