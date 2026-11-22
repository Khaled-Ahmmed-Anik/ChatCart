require "test_helper"

class ConversationRecoveryReliabilityTest < ActiveSupport::TestCase
  test "provider timeout retains the deterministic policy answer and cart" do
    order = pending_order
    message = order.conversation.messages.create!(sender_type: :customer, content: "delivery charge koto?")
    fallback = BotReplyGenerator.new(pending_order: order, customer_message: message, outcome: :delivery_charge_requested).content
    assistant = AiConversationAssistant.new(customer_message: message, pending_order: order,
      outcome: :delivery_charge_requested, api_key: "test-only")
    assistant.define_singleton_method(:naturalizer_enabled?) { true }
    assistant.define_singleton_method(:request_reply) { |_fallback| raise Net::ReadTimeout }
    assert_equal fallback, assistant.rewrite(fallback: fallback)
    assert_equal "Net::ReadTimeout", assistant.telemetry["fallback_reason"]
    assert_equal 2, order.reload.quantity
    assert_not_predicate order, :confirmed?
  end

  test "guardrail rejection exposes a reason code but never logs rejected text" do
    order = pending_order
    message = order.conversation.messages.create!(sender_type: :customer, content: "delivery charge koto?")
    assistant = AiConversationAssistant.new(customer_message: message, pending_order: order,
      outcome: :delivery_charge_requested, api_key: "test-only")
    assistant.define_singleton_method(:naturalizer_enabled?) { true }
    assistant.define_singleton_method(:request_reply) { |_fallback| "Only ৳9999 today!" }
    fallback = "The seller needs to confirm the delivery charge."
    assert_equal fallback, assistant.rewrite(fallback: fallback)
    assert_equal "guardrail_rejected", assistant.telemetry["fallback_reason"]
    assert_equal "unapproved_price", assistant.telemetry["guardrail_reason"]
    assert_not_includes assistant.telemetry.to_json, "9999"
  end

  private

  def pending_order
    business = Business.create!(name: "Recovery Shop", slug: "recovery-reliability")
    product = business.products.create!(name: "Recovery Product", price: 500, stock_quantity: 10)
    conversation = business.conversations.create!(channel: "facebook", external_customer_id: SecureRandom.uuid)
    conversation.pending_orders.create!(product: product, quantity: 2, status: :collecting_name)
  end
end
