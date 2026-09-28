require "test_helper"

class SubmitDeliveryJobTest < ActiveJob::TestCase
  test "skips submission without calling the provider when the business is inactive" do
    business = Business.create!(name: "Disabled Shop", slug: "disabled-shop")
    conversation = business.conversations.create!(channel: "facebook", external_customer_id: "customer-1")
    product = business.products.create!(name: "Product", price: 100, stock_quantity: 1)
    pending_order = conversation.create_pending_order!(
      product: product, quantity: 1, customer_name: "Buyer", phone: "01712345678",
      address: "Dhaka", status: :confirmed
    )
    order = business.orders.create!(
      conversation: conversation, pending_order: pending_order, number: "ORD-INACTIVE", customer_name: "Buyer",
      phone: "01712345678", address: "Dhaka", subtotal: 100, total: 100, confirmed_at: Time.current
    )
    integration = business.create_delivery_integration!(provider: "manual", active: true)
    submission = order.delivery_submissions.create!(delivery_integration: integration)
    business.update!(status: "disabled")

    with_sender_failure { SubmitDeliveryJob.perform_now(submission) }

    assert_equal "skipped", submission.reload.status
    assert_equal "business_inactive", submission.last_error
    assert_equal 0, submission.attempts
    assert_equal "confirmed", order.reload.status
  end

  private

  def with_sender_failure
    original_new = DeliverySubmissionSender.method(:new)
    DeliverySubmissionSender.define_singleton_method(:new) { |*| raise "Delivery provider must not be called" }
    yield
  ensure
    DeliverySubmissionSender.define_singleton_method(:new, original_new)
  end
end
