require "test_helper"
require_relative "../support/photo_test_stubs"

class ProcessMessengerImageJobTest < ActiveJob::TestCase
  include PhotoTestStubs
  setup do
    @business = Business.create!(name: "Photo Business", slug: "photo-business", default_language: "english")
    @product = @business.products.create!(name: "Blue Shirt", price: 500)
    @event = MessengerWebhookEvent.create!(business: @business, event_type: "customer_image", status: "received",
      sender_id: "photo-customer", external_event_id: "photo-mid", payload: { message: { attachments: [ { type: "image", payload: { url: "https://images.example.com/customer.png" } } ] } })
    @recognizer = Object.new
    product = @product
    @recognizer.define_singleton_method(:recognize) { product }
  end

  test "suggests one match asynchronously and duplicate processing cannot change an order" do
    assert_no_difference [ -> { PendingOrder.count }, -> { Order.count } ] do
      assert_difference -> { Message.count }, 2 do
        assert_enqueued_with(job: SendMessengerReplyJob) { run_job }
      end
    end
    assert_equal "processed", @event.reload.status
    assert_includes @event.messenger_delivery.message.content, "Blue Shirt"
    assert_includes @event.messenger_delivery.message.content, "yes, this one"
    assert_no_difference([ -> { Message.count }, -> { MessengerDelivery.count } ]) { run_job }
  end

  test "handed over conversation records photo but never calls recognition or sends a bot reply" do
    conversation = @business.conversations.create!(channel: "facebook", external_customer_id: @event.sender_id, status: :handed_over)
    with_photo_stub(CustomerPhotoRecognizer, :new, ->(**) { flunk "Must not call AI during takeover" }) do
      ProcessMessengerImageJob.perform_now(@event)
    end
    assert_equal 1, conversation.messages.customer.count
    assert_nil @event.reload.messenger_delivery
  end

  test "caption and photo suggestion cannot modify an existing cart or confirm it" do
    conversation = @business.conversations.create!(channel: "facebook", external_customer_id: @event.sender_id)
    cart = conversation.create_pending_order!(product: @product, quantity: 2, status: :awaiting_confirmation)
    original = cart.attributes
    payload = @event.payload.deep_dup
    payload["message"]["text"] = "Confirm this and make it ten"
    @event.update!(payload: payload)
    run_job
    assert_equal original, cart.reload.attributes
    assert_equal "Confirm this and make it ten", conversation.messages.customer.last.content
    assert_equal 0, conversation.orders.count
  end

  test "disabled business is ignored and has no messages" do
    @business.update!(status: "disabled")
    with_photo_stub(CustomerPhotoRecognizer, :new, ->(**) { flunk "Disabled business must not call AI" }) do
      assert_no_difference -> { Message.count } do
        ProcessMessengerImageJob.perform_now(@event)
      end
    end
    assert_equal "ignored", @event.reload.status
  end

  test "unrecognized photo sends localized helpful fallback" do
    @business.conversations.create!(channel: "facebook", external_customer_id: @event.sender_id,
      conversation_state: { preferred_language: "banglish" })
    @recognizer.define_singleton_method(:recognize) { nil }
    run_job
    assert_includes @event.reload.messenger_delivery.message.content, "Chobir jonno dhonnobad"
  end

  test "fresh processing claim is not processed concurrently" do
    @event.update!(status: "processing")
    assert_no_difference(-> { Message.count }) { run_job }
  end

  test "expired processing claim can be recovered" do
    @event.update_columns(status: "processing", updated_at: 10.minutes.ago)
    run_job
    assert_equal "processed", @event.reload.status
  end

  test "product deactivated during recognition is rechecked" do
    product = @product
    @recognizer.define_singleton_method(:recognize) { product.update!(active: false); product }
    run_job
    assert_nil @event.reload.messenger_delivery.message.metadata["suggested_product_id"]
  end

  test "takeover during recognition suppresses automated delivery" do
    conversation = @business.conversations.create!(channel: "facebook", external_customer_id: @event.sender_id)
    product = @product
    @recognizer.define_singleton_method(:recognize) { conversation.update!(status: :handed_over); product }
    run_job
    assert_nil @event.reload.messenger_delivery
    assert_equal 1, conversation.messages.customer.count
  end

  test "newer customer turn prevents a late photo reply from interrupting the flow" do
    conversation = @business.conversations.create!(channel: "facebook", external_customer_id: @event.sender_id)
    later_time = @event.created_at + 1.second
    conversation.messages.create!(sender_type: :customer, content: "Never mind, show delivery charges", created_at: later_time)
    conversation.update!(last_message_at: later_time)
    create_customer_event(created_at: later_time, external_event_id: "later-text")
    run_job
    assert_nil @event.reload.messenger_delivery
    assert_equal later_time.to_i, conversation.reload.last_message_at.to_i
  end

  test "earlier text processed after photo receipt does not suppress the recognized reply" do
    earlier_text = create_customer_event(created_at: @event.created_at - 1.second, external_event_id: "earlier-text")
    earlier_text.update!(status: "received")
    profile = Object.new
    profile.define_singleton_method(:name) { nil }
    with_photo_stub(MessengerCustomerProfile, :new, profile) { ProcessMessengerEventJob.perform_now(earlier_text) }
    conversation = @business.conversations.find_by!(channel: "facebook", external_customer_id: @event.sender_id)
    assert_operator conversation.messages.customer.last.created_at, :>, @event.created_at
    run_job
    assert_equal "processed", @event.reload.status
    assert_includes @event.messenger_delivery.message.content, @product.name
  end

  test "newer text receipt suppresses the photo even while text processing is pending" do
    create_customer_event(created_at: @event.created_at + 1.second, external_event_id: "pending-text", status: "received")
    run_job
    assert_equal "processed", @event.reload.status
    assert_nil @event.messenger_delivery
  end

  test "receipt ID resolves equal timestamps and ignores foreign customers businesses and receipts" do
    create_customer_event(created_at: @event.created_at - 1.second, external_event_id: "old-receipt")
    create_customer_event(created_at: @event.created_at + 1.second, external_event_id: "other-sender", sender_id: "another-customer")
    other_business = Business.create!(name: "Other receipts", slug: "other-receipts")
    create_customer_event(created_at: @event.created_at + 1.second, external_event_id: "other-business", business: other_business)
    create_customer_event(created_at: @event.created_at + 1.second, external_event_id: "ignored-receipt", status: "ignored")
    create_customer_event(created_at: @event.created_at + 1.second, external_event_id: "echo-receipt", event_type: "message_echo")
    job = ProcessMessengerImageJob.new
    refute job.send(:newer_customer_event?, @event)
    create_customer_event(created_at: @event.created_at, external_event_id: "same-time-later-id")
    assert job.send(:newer_customer_event?, @event)
  end

  test "disabling business while vision runs prevents persistence of a reply" do
    business = @business
    product = @product
    @recognizer.define_singleton_method(:recognize) { business.update!(status: "disabled"); product }
    run_job
    assert_equal "ignored", @event.reload.status
    assert_nil @event.messenger_delivery
  end

  test "a foreign tenant product cannot be suggested even if a recognizer returns it" do
    foreign_business = Business.create!(name: "Foreign", slug: "foreign-photo-test")
    foreign_product = foreign_business.products.create!(name: "Foreign Secret", price: 20)
    @recognizer.define_singleton_method(:recognize) { foreign_product }
    run_job
    refute_includes @event.reload.messenger_delivery.message.content, "Foreign Secret"
    assert_nil @event.messenger_delivery.message.metadata["suggested_product_id"]
  end

  private

  def create_customer_event(**attributes)
    MessengerWebhookEvent.create!({ business: @business, event_type: "customer_text", status: "processed",
      sender_id: @event.sender_id, payload: { message: { text: "Delivery charge?" } } }.merge(attributes))
  end

  def run_job
    with_photo_stub(CustomerPhotoRecognizer, :new, @recognizer) { ProcessMessengerImageJob.perform_now(@event) }
  end
end
