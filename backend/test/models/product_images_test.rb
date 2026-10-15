require "test_helper"

class ProductImagesTest < ActiveSupport::TestCase
  test "retains HTTPS query parameters and rejects overlong links" do
    url = "https://cdn.example.com/image.jpg?signature=example&width=500"
    product = Product.new(name: "Signed image", price: 100, stock_quantity: 1, image_urls: [ url ])
    assert product.valid?
    assert_equal [ url ], product.image_urls
    product.image_urls = [ "https://cdn.example.com/#{'a' * Constants::ProductImages::MAX_URL_LENGTH}.jpg" ]
    assert_not product.valid?
    assert_includes product.errors.full_messages.join, Constants::ProductImages::MAX_URL_LENGTH.to_s
  end
  test "normalizes image links while preserving cover order and allows clearing" do
    product = Product.create!(name: "Images", price: 100, stock_quantity: 1,
      image_urls: [ " https://cdn.example.com/cover.jpg ", "", "https://cdn.example.com/other.png", "https://cdn.example.com/cover.jpg" ])
    assert_equal [ "https://cdn.example.com/cover.jpg", "https://cdn.example.com/other.png" ], product.reload.image_urls
    product.update!(image_urls: [])
    assert_empty product.reload.image_urls
  end

  test "rejects unsafe or unsupported image links without making network requests" do
    [ "http://cdn.example.com/image.jpg", "javascript:alert(1)", "data:image/png;base64,AAAA",
      "https://user:password@cdn.example.com/image.jpg", "https://cdn.example.com:8443/image.jpg",
      "https://localhost/image.jpg", "https://127.0.0.1/image.jpg", "https://[::1]/image.jpg",
      "https://images.local/image.jpg", "not a URL" ].each do |url|
      product = Product.new(name: "Invalid image", price: 100, stock_quantity: 1, image_urls: [ url ])
      assert_not product.valid?, url
      assert product.errors.of_kind?(:image_urls, :invalid_image_url), url
    end
  end

  test "limits galleries with a localized count error" do
    product = Product.new(name: "Too many", price: 100, stock_quantity: 1,
      image_urls: (0..Constants::ProductImages::MAX_IMAGES).map { |index| "https://cdn.example.com/#{index}.jpg" })
    assert_not product.valid?
    assert product.errors.of_kind?(:image_urls, :too_many_images)
    I18n.with_locale(:bn) do
      assert_includes product.errors.full_messages.join, Constants::ProductImages::MAX_IMAGES.to_s
      assert_not_includes product.errors.full_messages.join, "Translation missing"
    end
  end

  test "existing legacy image links do not prevent unrelated edits" do
    product = Product.create!(name: "Legacy", price: 100, stock_quantity: 1)
    product.update_columns(image_urls: [ "http://legacy.example.com/image.jpg" ])
    product.reload.update!(price: 200)
    assert_equal 200, product.reload.price
    assert_not product.update(image_urls: [ "http://changed.example.com/image.jpg" ])
  end
end
