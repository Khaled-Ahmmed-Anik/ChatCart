require "test_helper"

class Api::ProductImagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @business = Business.create!(name: "Image API", slug: "image-api")
    @token, digest = User.issue_token
    @user = @business.users.create!(name: "Owner", email: "image-owner@example.test", role: "owner", api_token_digest: digest)
    @product = @business.products.create!(name: "API Product", price: 100, stock_quantity: 1)
  end

  test "REST image edits use the same validation and allow clearing" do
    patch api_product_path(@product), params: { product: { image_urls: [ "https://cdn.example.com/front.jpg" ] } }, headers: authorization, as: :json
    assert_response :success
    assert_equal [ "https://cdn.example.com/front.jpg" ], @product.reload.image_urls
    patch api_product_path(@product), params: { product: { image_urls: [ "http://cdn.example.com/unsafe.jpg" ] } }, headers: authorization, as: :json
    assert_response :unprocessable_entity
    assert_equal [ "https://cdn.example.com/front.jpg" ], @product.reload.image_urls
    patch api_product_path(@product), params: { product: { image_urls: [] } }, headers: authorization, as: :json
    assert_response :success
    assert_empty @product.reload.image_urls
  end

  test "non-management users cannot change product images" do
    @user.update!(role: "analyst")
    patch api_product_path(@product), params: { product: { image_urls: [ "https://cdn.example.com/a.jpg" ] } }, headers: authorization, as: :json
    assert_response :forbidden
    assert_empty @product.reload.image_urls
  end

  private

  def authorization
    { "Authorization" => "Bearer #{@token}" }
  end
end
