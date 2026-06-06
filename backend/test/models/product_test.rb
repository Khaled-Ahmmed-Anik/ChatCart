require "test_helper"

class ProductTest < ActiveSupport::TestCase
  test "active scope returns only active products" do
    active_product = create_product(name: "Active Product", active: true)
    create_product(name: "Inactive Product", active: false)

    assert_equal [active_product], Product.active.to_a
  end

  test "in_stock scope returns only products with stock" do
    in_stock_product = create_product(name: "In Stock", stock_quantity: 1)
    create_product(name: "Out Of Stock", stock_quantity: 0)

    assert_equal [in_stock_product], Product.in_stock.to_a
  end

  test "validates required and non-negative attributes" do
    product = Product.new(name: nil, price: -1, stock_quantity: -1)

    assert_not product.valid?
    assert_includes product.errors[:name], "can't be blank"
    assert_includes product.errors[:price], "must be greater than or equal to 0"
    assert_includes product.errors[:stock_quantity], "must be greater than or equal to 0"
  end

  test "available_for_quantity returns true when active product has enough stock" do
    product = create_product(stock_quantity: 3, active: true)

    assert product.available_for_quantity?(2)
  end

  test "available_for_quantity returns false when unavailable" do
    inactive_product = create_product(name: "Inactive", stock_quantity: 3, active: false)
    low_stock_product = create_product(name: "Low Stock", stock_quantity: 1, active: true)

    assert_not inactive_product.available_for_quantity?(1)
    assert_not low_stock_product.available_for_quantity?(2)
    assert_not low_stock_product.available_for_quantity?(0)
  end

  private

  def create_product(attributes = {})
    Product.create!(
      {
        name: "Fresh Musk",
        price: 750,
        stock_quantity: 10
      }.merge(attributes)
    )
  end
end
