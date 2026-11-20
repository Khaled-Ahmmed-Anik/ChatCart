require "test_helper"
require_relative "../support/conversation_journey_assertions"

class ConversationTurnDecisionTest < ActiveSupport::TestCase
  include ConversationJourneyAssertions

  setup do
    @business = Business.create!(name: "Decision Shop", slug: "decision-shop", category: "electronics")
    @product = @business.products.create!(name: "Anker Charger", category: "charger", price: 1849, stock_quantity: 10)
    @conversation = @business.conversations.create!(channel: "facebook", external_customer_id: "decision")
    @order = @conversation.create_pending_order!
    ConversationMemory.new(@conversation).remember_options!(kind: :products, records: [ @product ])
  end

  test "decision proposal is read only and purchase acceptance precedes discovery" do
    message = @conversation.messages.create!(sender_type: :customer, content: "charger ta")
    before = @order.attributes
    decision = ConversationTurnDecision.new(message: message, pending_order: @order).call
    assert_equal :select, decision.route
    assert_equal @product.id, decision.product.id
    assert_equal before, @order.reload.attributes
    assert_equal "select", decision.metadata["route"]
  end

  test "factual questions and browsing cannot propose a write" do
    [ "What is the Anker Charger price?", "Ei charger er cable thakbe?", "I am just browsing, do not place an order." ].each do |text|
      message = @conversation.messages.create!(sender_type: :customer, content: text)
      assert_equal :answer, ConversationTurnDecision.new(message: message, pending_order: @order).call.route
      assert_nil @order.reload.product_id
    end
  end

  test "terminal cancellation is never proposed as an executable cancel" do
    @order.update!(product: @product, quantity: 1, status: :confirmed)
    message = @conversation.messages.create!(sender_type: :customer, content: "cancel")
    refute_equal :cancel, ConversationTurnDecision.new(message: message, pending_order: @order).call.route
    assert_predicate @order.reload, :confirmed?
  end

  test "Bengali explicit sizes retain the existing variant inquiry path" do
    message = @conversation.messages.create!(sender_type: :customer, content: "Anker Charger ১০ মিলি দাম কত?")
    assert_equal :commerce, ConversationTurnDecision.new(message: message, pending_order: @order).call.route
  end

  test "saved telemetry separates routing from actual persisted outcome" do
    result = assert_conversation_journey(business: @business, steps: [
      { say: "charger ase?" }, { say: "charger ta", order: { product_id: @product.id, quantity: nil } }
    ]).last
    assert_equal "select", result.message.reload.metadata.dig("routing_decision", "route")
    assert_equal "product_selected", result.message.metadata.dig("conversation_intelligence", "outcome")
    assert_equal @product.id, result.message.metadata.dig("routing_decision", "product_id")
  end
end
