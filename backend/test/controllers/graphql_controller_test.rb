require "test_helper"

class GraphqlControllerTest < ActionDispatch::IntegrationTest
  setup do
    @business = Business.create!(name: "Alpha", slug: "graphql-alpha", category: "retail")
    @other_business = Business.create!(name: "Beta", slug: "graphql-beta", category: "retail")
    @token, digest = User.issue_token
    @user = @business.users.create!(
      name: "Owner", email: "graphql-owner@alpha.test", role: "owner", api_token_digest: digest
    )
  end

  test "requires authentication" do
    post graphql_path, params: { query: "{ currentBusiness { id } }" }, as: :json

    assert_response :unauthorized
    assert_equal "Unauthorized", JSON.parse(response.body).dig("errors", 0, "message")
  end

  test "returns viewer business analytics and tenant scoped products" do
    product = @business.products.create!(name: "Alpha Product", price: 100, stock_quantity: 5)
    @other_business.products.create!(name: "Beta Product", price: 200, stock_quantity: 5)
    conversation = @business.conversations.create!(channel: "facebook", external_customer_id: "buyer")
    create_order(conversation, product)

    post graphql_path, params: { query: <<~GRAPHQL }, headers: authorization, as: :json
      query Dashboard {
        viewer { id name role }
        currentBusiness { id name currency }
        analytics { conversations confirmedOrders revenue }
        products { id name price stockQuantity active }
      }
    GRAPHQL

    assert_response :success
    data = JSON.parse(response.body).fetch("data")
    assert_equal @user.id.to_s, data.dig("viewer", "id")
    assert_equal @business.id.to_s, data.dig("currentBusiness", "id")
    assert_equal 1, data.dig("analytics", "confirmedOrders")
    assert_equal [ product.id.to_s ], data.fetch("products").pluck("id")
  end

  test "creates and updates products inside the authenticated business" do
    mutation = <<~GRAPHQL
      mutation SaveProduct($id: ID, $input: ProductInput!) {
        saveProduct(id: $id, input: $input) { product { id name stockQuantity } errors }
      }
    GRAPHQL
    input = { name: "New Product", price: "250", stockQuantity: 8, active: true }

    post graphql_path, params: { query: mutation, variables: { input: input } }, headers: authorization, as: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert_empty body.dig("data", "saveProduct", "errors")
    product = @business.products.find(body.dig("data", "saveProduct", "product", "id"))
    assert_equal "New Product", product.name

    post graphql_path,
      params: { query: mutation, variables: { id: product.id, input: input.merge(name: "Updated Product") } },
      headers: authorization, as: :json

    assert_equal "Updated Product", product.reload.name
  end

  test "cannot update another business product" do
    product = @other_business.products.create!(name: "Private", price: 100, stock_quantity: 1)
    mutation = <<~GRAPHQL
      mutation SaveProduct($id: ID, $input: ProductInput!) {
        saveProduct(id: $id, input: $input) { product { id } errors }
      }
    GRAPHQL

    post graphql_path, params: {
      query: mutation,
      variables: { id: product.id, input: { name: "Stolen", price: "1", stockQuantity: 1 } }
    }, headers: authorization, as: :json

    assert_response :success
    assert_equal "Record not found", JSON.parse(response.body).dig("errors", 0, "message")
    assert_equal "Private", product.reload.name
  end

  test "creates rich product knowledge and variants" do
    mutation = <<~GRAPHQL
      mutation SaveProduct($input: ProductInput!) {
        saveProduct(input: $input) {
          product { name category benefits variants { name size price stockQuantity } }
          errors
        }
      }
    GRAPHQL
    input = {
      name: "The Oud", price: "250", stockQuantity: 0, category: "Fragrance",
      benefits: "Deep woody profile", productAttributes: { longevity: "8 hours" },
      variants: [
        { name: "3 ml", size: "3 ml", price: "250", stockQuantity: 10 },
        { name: "6 ml", size: "6 ml", price: "450", stockQuantity: 5 }
      ]
    }

    post graphql_path, params: { query: mutation, variables: { input: input } }, headers: authorization, as: :json

    assert_response :success
    payload = JSON.parse(response.body).dig("data", "saveProduct")
    assert_empty payload["errors"]
    assert_equal "Fragrance", payload.dig("product", "category")
    assert_equal [ "3 ml", "6 ml" ], payload.dig("product", "variants").pluck("size")
    assert_equal 2, @business.products.find_by!(name: "The Oud").product_variants.count
  end

  private

  def authorization
    { "Authorization" => "Bearer #{@token}" }
  end

  def create_order(conversation, product)
    pending_order = conversation.create_pending_order!(
      product: product, quantity: 1, customer_name: "Buyer", phone: "01712345678",
      address: "Dhaka", status: :confirmed
    )
    order = @business.orders.create!(
      conversation: conversation, pending_order: pending_order, number: "GRAPHQL-1", customer_name: "Buyer",
      phone: "01712345678", address: "Dhaka", subtotal: 100, total: 100, confirmed_at: Time.current
    )
    order.order_items.create!(product: product, product_name: product.name, quantity: 1, unit_price: 100, total: 100)
  end
end
