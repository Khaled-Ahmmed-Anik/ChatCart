require "test_helper"
require_relative "../support/photo_test_stubs"
require "vips"

class PublicProductImageFetcherTest < ActiveSupport::TestCase
  include PhotoTestStubs
  class FakeHTTP
    attr_accessor :ipaddr, :use_ssl, :open_timeout, :read_timeout, :write_timeout
    attr_reader :request_uri

    def initialize(response, bytes)
      @response, @bytes = response, bytes
    end

    def request(request)
      @request_uri = request.path
      @response.define_singleton_method(:read_body) { |&block| block.call(@test_bytes) }
      @response.instance_variable_set(:@test_bytes, @bytes)
      yield @response
    end
  end

  setup do
    @fetcher = PublicProductImageFetcher.new
    @fetcher.define_singleton_method(:resolve_addresses) { |_host| [ "8.8.8.8" ] }
  end

  test "pins public DNS address and validates PNG bytes without logging URLs" do
    bytes = Vips::Image.black(80, 60, bands: 3).write_to_buffer(".png")
    http = FakeHTTP.new(response("image/png"), bytes)
    with_photo_stub(Net::HTTP, :new, ->(host, port, proxy) { assert_equal "images.example.com", host; assert_equal 443, port; assert_nil proxy; http }) do
      image = @fetcher.fetch("https://images.example.com/photo.png?signature=secret")
      decoded = Vips::Image.new_from_buffer(Base64.strict_decode64(image.data), "")
      assert_equal [ 80, 60 ], [ decoded.width, decoded.height ]
      assert_equal "image/jpeg", image.mime_type
    end
    assert_equal "8.8.8.8", http.ipaddr
    assert_equal true, http.use_ssl
  end

  test "rejects private mixed DNS and nonpublic IPv6 before connecting" do
    %w[127.0.0.1 10.0.0.1 169.254.169.254 100.64.0.1 ::1 ::ffff:127.0.0.1 fd00::1 2001:db8::1].each do |address|
      @fetcher.define_singleton_method(:resolve_addresses) { |_host| [ "8.8.8.8", address ] }
      with_photo_stub(Net::HTTP, :new, ->(*) { flunk "Unsafe address must never connect" }) do
        assert_raises(PublicProductImageFetcher::UnsafeImage) { @fetcher.fetch("https://images.example.com/a") }
      end
    end
  end

  test "larger downloaded photo is normalized while the model payload stays bounded" do
    bytes = Vips::Image.gaussnoise(2000, 1500).cast(:uchar).write_to_buffer(".png")
    assert_operator bytes.bytesize, :>, Constants::PhotoRecognition::MAX_IMAGE_BYTES
    with_photo_stub(Net::HTTP, :new, FakeHTTP.new(response("image/png"), bytes)) do
      result = @fetcher.fetch("https://images.example.com/phone-photo.png")
      assert_equal "image/jpeg", result.mime_type
      assert_operator Base64.strict_decode64(result.data).bytesize, :<=, Constants::PhotoRecognition::MAX_IMAGE_BYTES
    end
  end

  test "rejects credentials localhost IP URLs and insecure schemes" do
    %w[http://images.example.com/a https://user:pass@images.example.com/a https://127.0.0.1/a https://service.local/a].each do |url|
      assert_raises(PublicProductImageFetcher::UnsafeImage) { @fetcher.fetch(url) }
    end
  end

  test "rejects redirects HTML spoofed signatures and oversized streams" do
    cases = [
      [ Net::HTTPFound.new("1.1", "302", "Found"), "" ],
      [ response("text/html"), "<html>" ],
      [ response("image/png"), "<html>" ],
      [ response("image/png"), "x" * (Constants::PhotoRecognition::MAX_DOWNLOAD_BYTES + 1) ]
    ]
    cases.each do |http_response, bytes|
      with_photo_stub(Net::HTTP, :new, FakeHTTP.new(http_response, bytes)) do
        assert_raises(PublicProductImageFetcher::UnsafeImage) { @fetcher.fetch("https://images.example.com/a") }
      end
    end
  end

  private

  def response(mime)
    Net::HTTPOK.new("1.1", "200", "OK").tap { |response| response["content-type"] = mime }
  end
end
