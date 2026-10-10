require "test_helper"
require "net/http"

class MessengerCustomerProfileTest < ActiveSupport::TestCase
  test "returns the Messenger profile name" do
    response = Struct.new(:body) do
      def is_a?(klass) = klass == Net::HTTPSuccess ? true : super
    end.new({ name: "Khaled Anik" }.to_json)

    with_http_response(response) do
      assert_equal "Khaled Anik", MessengerCustomerProfile.new(sender_id: "psid-123", page_access_token: "token").name
    end
  end

  test "fails quietly when Messenger profile lookup is unavailable" do
    with_http_error(Net::ReadTimeout.new) do
      assert_nil MessengerCustomerProfile.new(sender_id: "psid-123", page_access_token: "token").name
    end
  end

  private

  def with_http_response(response)
    original_start = Net::HTTP.method(:start)
    fake_http = Object.new
    fake_http.define_singleton_method(:request) { |_request| response }
    Net::HTTP.define_singleton_method(:start) { |*_arguments, **_options, &block| block.call(fake_http) }
    yield
  ensure
    Net::HTTP.define_singleton_method(:start, original_start)
  end

  def with_http_error(error)
    original_start = Net::HTTP.method(:start)
    Net::HTTP.define_singleton_method(:start) { |*_arguments, **_options| raise error }
    yield
  ensure
    Net::HTTP.define_singleton_method(:start, original_start)
  end
end
