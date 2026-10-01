require "test_helper"
require "net/http"

class SendMessengerReplyJobTest < ActiveJob::TestCase
  setup do
    @previous_token = ENV["MESSENGER_PAGE_ACCESS_TOKEN"]
    ENV["MESSENGER_PAGE_ACCESS_TOKEN"] = "token-123"
  end

  teardown do
    ENV["MESSENGER_PAGE_ACCESS_TOKEN"] = @previous_token
  end

  test "records a successful delivery" do
    delivery = create_delivery
    response = fake_response(success: true, code: 200, body: '{"message_id":"sent-1"}')

    with_http_post_stub(->(*) { response }) do
      SendMessengerReplyJob.perform_now(delivery)
    end

    delivery.reload
    assert_equal "delivered", delivery.status
    assert_equal 1, delivery.attempts
    assert_equal 200, delivery.response_code
    assert delivery.delivered_at.present?
    assert_nil delivery.last_error
  end

  test "records a permanent failure without retrying" do
    delivery = create_delivery
    response = fake_response(success: false, code: 400, body: '{"error":"invalid recipient"}')

    assert_no_enqueued_jobs only: SendMessengerReplyJob do
      with_http_post_stub(->(*) { response }) do
        SendMessengerReplyJob.perform_now(delivery)
      end
    end

    delivery.reload
    assert_equal "failed", delivery.status
    assert_equal 1, delivery.attempts
    assert_equal 400, delivery.response_code
    assert_equal "Messenger API returned HTTP 400", delivery.last_error
  end

  test "records a temporary failure and schedules a retry" do
    delivery = create_delivery
    response = fake_response(success: false, code: 503, body: '{"error":"unavailable"}')

    assert_enqueued_with(job: SendMessengerReplyJob) do
      with_http_post_stub(->(*) { response }) do
        SendMessengerReplyJob.perform_now(delivery)
      end
    end

    delivery.reload
    assert_equal "retrying", delivery.status
    assert_equal 1, delivery.attempts
    assert_equal 503, delivery.response_code
  end

  test "skips delivery without an API call when the business is inactive" do
    delivery = create_delivery
    delivery.messenger_webhook_event.business.update!(status: "disabled")

    with_http_post_stub(->(*) { flunk("Messenger API must not be called") }) do
      SendMessengerReplyJob.perform_now(delivery)
    end

    assert_equal "skipped", delivery.reload.status
    assert_equal "business_inactive", delivery.last_error
    assert_equal 0, delivery.attempts
  end

  private

  def create_delivery
    conversation = Conversation.create!(channel: "facebook", external_customer_id: "fb-user-123")
    message = conversation.messages.create!(sender_type: :bot, content: "Hello")
    event = MessengerWebhookEvent.create!(
      event_type: "customer_text",
      external_event_id: SecureRandom.uuid,
      sender_id: "fb-user-123",
      payload: { message: { text: "Hi" } },
      status: "processed",
      processed_at: Time.current
    )
    MessengerDelivery.create!(messenger_webhook_event: event, message: message, recipient_id: "fb-user-123")
  end

  def fake_response(success:, code:, body: "")
    Struct.new(:success, :code, :body) do
      def is_a?(klass)
        klass == Net::HTTPSuccess ? success : super
      end
    end.new(success, code.to_s, body)
  end

  def with_http_post_stub(stub)
    original_post = Net::HTTP.method(:post)
    Net::HTTP.define_singleton_method(:post, &stub)
    yield
  ensure
    Net::HTTP.define_singleton_method(:post, original_post)
  end
end
