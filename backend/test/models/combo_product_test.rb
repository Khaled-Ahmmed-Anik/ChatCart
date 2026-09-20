require "test_helper"

class ComboProductTest < ActiveSupport::TestCase
  test "derives fixed combo stock from required components" do
    business = Business.create!(name: "Combo Shop", slug: "combo-shop")
    blush = business.products.create!(name: "The Blush", price: 500, stock_quantity: 8)
    desire = business.products.create!(name: "The Desire", price: 600, stock_quantity: 5)
    combo = business.products.create!(
      name: "Combo for Her", product_type: "fixed_combo", stock_strategy: "component_derived",
      price: 1200, stock_quantity: 0
    )
    combo.combo_items.create!(component_product: blush, quantity: 2)
    combo.combo_items.create!(component_product: desire, quantity: 1)

    assert_equal 4, combo.total_available_stock
    assert_equal [ "The Blush", "The Desire" ], combo.component_snapshot.pluck("name")
  end

  test "prevents permanent deletion when a product is part of a combo" do
    business = Business.create!(name: "Protected Combo Shop", slug: "protected-combo-shop")
    component = business.products.create!(name: "Component", price: 100, stock_quantity: 5)
    combo = business.products.create!(name: "Combo", product_type: "fixed_combo", price: 100, stock_quantity: 2)
    combo.combo_items.create!(component_product: component)

    assert_not component.deletable?
    assert combo.deletable?
  end
end
