require "test_helper"
require_relative "../support/photo_test_stubs"

class CustomerPhotoRecognizerTest < ActiveSupport::TestCase
  include PhotoTestStubs
  setup do
    @previous = ENV.to_h.slice("CUSTOMER_PHOTO_RECOGNITION_ENABLED", "GEMINI_API_KEY")
    ENV["CUSTOMER_PHOTO_RECOGNITION_ENABLED"] = "true"
    ENV["GEMINI_API_KEY"] = "fake-test-key"
    @business = Business.create!(name: "Photo Shop", slug: "photo-shop")
    @product = @business.products.create!(name: "Blue Shirt", price: 500, image_urls: [ "https://images.example.com/front.png", "https://images.example.com/back.png" ])
    @fetcher = Object.new
    @fetcher.define_singleton_method(:fetch) { |_url| PublicProductImageFetcher::Image.new(mime_type: "image/png", data: "ZmFrZQ==") }
  end

  teardown do
    %w[CUSTOMER_PHOTO_RECOGNITION_ENABLED GEMINI_API_KEY].each { |key| ENV[key] = @previous[key] }
  end

  test "compares multiple customer and reference photos without loading another business" do
    other = Business.create!(name: "Other", slug: "other-photo-shop")
    other_product = other.products.create!(name: "Private Product", price: 100)
    recognizer = build_recognizer(urls: %w[https://images.example.com/customer.png https://images.example.com/customer2.png])
    recognizer.define_singleton_method(:request_match) do |parts|
      raise "Wrong number of images" unless parts.count { |part| part[:inlineData] } == 4
      raise "Cross tenant leak" if parts.to_json.include?("Private Product")

      { "product_id" => @test_id, "confidence" => 0.95 }
    end
    recognizer.instance_variable_set(:@test_id, @product.id)
    assert_equal @product, recognizer.recognize
    recognizer.instance_variable_set(:@test_id, other_product.id)
    assert_nil recognizer.recognize
  end

  test "rejects low invalid and out of range confidence or unknown IDs" do
    [ 0.4, -1, 2, "NaN", "bad" ].each do |confidence|
      recognizer = build_recognizer
      with_photo_stub(recognizer, :request_match, { "product_id" => @product.id, "confidence" => confidence }) do
        assert_nil recognizer.recognize
      end
    end
  end

  test "disabled flag missing key or too many photos never fetches" do
    test_case = self
    @fetcher.define_singleton_method(:fetch) { |_| test_case.flunk "Must not fetch" }
    ENV["CUSTOMER_PHOTO_RECOGNITION_ENABLED"] = "false"
    assert_nil build_recognizer.recognize
    ENV["CUSTOMER_PHOTO_RECOGNITION_ENABLED"] = "true"
    ENV["GEMINI_API_KEY"] = ""
    assert_nil build_recognizer.recognize
    ENV["GEMINI_API_KEY"] = "fake-test-key"
    assert_nil build_recognizer(urls: Array.new(4, "https://images.example.com/a")).recognize
  end

  test "catalogues beyond the bounded limit fall back without downloading" do
    Constants::PhotoRecognition::MAX_PRODUCTS.times { |index| @business.products.create!(name: "Extra #{index}", price: 100) }
    test_case = self
    @fetcher.define_singleton_method(:fetch) { |_| test_case.flunk "Must not fetch" }
    assert_nil build_recognizer.recognize
  end

  test "provider failure and inaccessible reference photos fall back" do
    recognizer = build_recognizer
    with_photo_stub(recognizer, :request_match, ->(*) { raise Net::ReadTimeout }) { assert_nil recognizer.recognize }
    @fetcher.define_singleton_method(:fetch) { |_| raise PublicProductImageFetcher::UnsafeImage }
    assert_nil build_recognizer.recognize
  end

  test "inactive products and products without reference photos cannot be returned" do
    @product.update!(active: false)
    recognizer = build_recognizer
    with_photo_stub(recognizer, :request_match, ->(*) { flunk "No catalogue references must not call AI" }) do
      assert_nil recognizer.recognize
    end
  end

  test "fractional model product IDs are rejected rather than truncated" do
    recognizer = build_recognizer
    with_photo_stub(recognizer, :request_match, { "product_id" => @product.id + 0.5, "confidence" => 0.99 }) do
      assert_nil recognizer.recognize
    end
  end

  test "real request builder uses inline data structured output and the configured key" do
    http = Object.new
    %i[use_ssl open_timeout read_timeout write_timeout].each { |attribute| http.define_singleton_method("#{attribute}=") { |_| } }
    expected_id = @product.id
    http.define_singleton_method(:request) do |request|
      body = JSON.parse(request.body)
      raise "Missing inline images" unless body.fetch("contents").first.fetch("parts").any? { |part| part["inlineData"] }
      raise "Missing key" unless request["x-goog-api-key"] == "fake-test-key"
      response = Net::HTTPOK.new("1.1", "200", "OK")
      response.define_singleton_method(:body) { { candidates: [ { content: { parts: [ { text: { product_id: expected_id, confidence: 0.9 }.to_json } ] } } ] }.to_json }
      response
    end
    with_photo_stub(Net::HTTP, :new, http) { assert_equal @product, build_recognizer.recognize }
  end

  private

  def build_recognizer(urls: [ "https://images.example.com/customer.png" ])
    CustomerPhotoRecognizer.new(business: @business, urls: urls, fetcher: @fetcher)
  end
end
