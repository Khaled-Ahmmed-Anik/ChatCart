require "test_helper"

class CatalogueOptionResolverTest < ActiveSupport::TestCase
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
