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
    assert_equal true, serialized_product["active"]
  end

  test "create adds a product" do
    assert_difference -> { Product.count }, 1 do
      post products_url, params: {
        product: {
          name: "The Party",
          price: 999,
          stock_quantity: 12,
          description: "A modern, vibrant scent with bold and sweet energy.",
          tags: "party,sweet,vibrant,bold",
          active: true
        }
      }, as: :json
    end

    assert_response :created

    response_body = JSON.parse(response.body)
    product = Product.find(response_body["id"])

    assert_equal "The Party", product.name
    assert_equal 999.to_d, product.price
    assert_equal 12, product.stock_quantity
    assert_equal "A modern, vibrant scent with bold and sweet energy.", product.description
    assert_equal "party,sweet,vibrant,bold", product.tags
    assert_equal true, product.active

    assert_equal product.id, response_body["id"]
    assert_equal "The Party", response_body["name"]
    assert_equal "999.0", response_body["price"]
    assert_equal 12, response_body["stock_quantity"]
    assert_equal "A modern, vibrant scent with bold and sweet energy.", response_body["description"]
    assert_equal "party,sweet,vibrant,bold", response_body["tags"]
    assert_equal true, response_body["active"]
  end

  test "create returns validation errors" do
    assert_no_difference -> { Product.count } do
      post products_url, params: {
        product: {
          name: "",
          price: -1,
          stock_quantity: -1
        }
      }, as: :json
    end

    assert_response :unprocessable_entity

    response_body = JSON.parse(response.body)
    assert_equal ["Name can't be blank"], response_body.dig("errors", "name")
    assert_equal ["Price must be greater than or equal to 0"], response_body.dig("errors", "price")
    assert_equal ["Stock quantity must be greater than or equal to 0"], response_body.dig("errors", "stock_quantity")
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
