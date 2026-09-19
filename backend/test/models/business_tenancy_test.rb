require "test_helper"

class BusinessTenancyTest < ActiveSupport::TestCase
  test "the same channel customer can exist for different businesses" do
    first = Business.create!(name: "First", slug: "first")
    second = Business.create!(name: "Second", slug: "second")

    first.conversations.create!(channel: "facebook", external_customer_id: "customer-1")

    assert second.conversations.create!(channel: "facebook", external_customer_id: "customer-1").persisted?
  end

  test "business policy is used for conversational delivery answers" do
    business = Business.create!(name: "First", slug: "first")
    business.create_business_policy!(delivery_charges: "Dhaka delivery is ৳80.")
    conversation = business.conversations.create!(channel: "facebook", external_customer_id: "customer-1")
    order = conversation.create_pending_order!
    message = conversation.messages.create!(sender_type: :customer, content: "delivery charge?")

    reply = BotReplyGenerator.new(
      pending_order: order, customer_message: message, outcome: :delivery_charge_requested
    ).content

    assert_equal "Dhaka delivery is ৳80.", reply
  end
end
