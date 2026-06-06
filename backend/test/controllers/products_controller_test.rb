require "test_helper"

class ProductsControllerTest < ActionDispatch::IntegrationTest
  test "index returns active products with stock ordered by name" do
    vanilla = create_product(name: "Vanilla Night", stock_quantity: 6)
    fresh = create_product(name: "Fresh Musk", stock_quantity: 10)
    create_product(name: "Inactive Product", active: false, stock_quantity: 10)
    create_product(name: "Out Of Stock", stock_quantity: 0)

    get products_url

    assert_response :success

    response_body = JSON.parse(response.body)
    assert_equal 2, response_body.length
    assert_equal ["Fresh Musk", "Vanilla Night"], response_body.map { |product| product["name"] }
    assert_equal fresh.id, response_body.first["id"]
    assert_equal vanilla.id, response_body.second["id"]
  end

  test "index serializes product fields for the bot layer" do
    product = create_product(
      name: "Fresh Musk",
      woo_commerce_product_id: "woo-123",
      price: 750,
      stock_quantity: 10,
      description: "Clean daily musk.",
      tags: "fresh,office,daily,musk"
    )

    get products_url

    assert_response :success

    serialized_product = JSON.parse(response.body).first
    assert_equal product.id, serialized_product["id"]
    assert_equal "Fresh Musk", serialized_product["name"]
    assert_equal "woo-123", serialized_product["woo_commerce_product_id"]
    assert_equal "750.0", serialized_product["price"]
    assert_equal 10, serialized_product["stock_quantity"]
    assert_equal "Clean daily musk.", serialized_product["description"]
    assert_equal "fresh,office,daily,musk", serialized_product["tags"]
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
