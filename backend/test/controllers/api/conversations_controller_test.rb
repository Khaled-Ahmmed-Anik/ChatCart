require "test_helper"

class Api::ConversationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @business = Business.create!(name: "Alpha", slug: "alpha-conversations", category: "retail")
    token, digest = User.issue_token
    @business.users.create!(name: "Owner", email: "owner@alpha-conversations.test", role: "owner", api_token_digest: digest)
    @headers = { "Authorization" => "Bearer #{token}" }
  end

  test "returns the cached Messenger customer name and external id" do
    conversation = @business.conversations.create!(
      channel: "facebook",
      external_customer_id: "psid-123",
      conversation_state: { customer_profile: { name: "Khaled Anik", source: "messenger" } }
    )

    get api_conversations_path, headers: @headers

    assert_response :success
    item = JSON.parse(response.body).find { |record| record.fetch("id") == conversation.id }
    assert_equal "Khaled Anik", item.fetch("customer_name")
    assert_equal "psid-123", item.fetch("external_customer_id")
  end

  test "falls back to the latest captured order name" do
    conversation = @business.conversations.create!(channel: "facebook", external_customer_id: "psid-456")
    conversation.pending_orders.create!(customer_name: "Order Customer")

    get api_conversation_path(conversation), headers: @headers

    assert_response :success
    assert_equal "Order Customer", JSON.parse(response.body).fetch("customer_name")
  end

  test "read-only context exposes captured customer fields and multi-item draft subtotal without inventing fees" do
    conversation = @business.conversations.create!(channel: "facebook", external_customer_id: "context-buyer")
    first = @business.products.create!(name: "Shirt", price: 100, stock_quantity: 20)
    second = @business.products.create!(name: "Shoes", price: 300, stock_quantity: 20)
    pending = conversation.create_pending_order!(product: first, quantity: 2, phone: "01712345678", address: "Dhaka")
    pending.pending_order_items.create!(product: second, quantity: 1)

    get api_conversation_path(conversation), headers: @headers

    assert_response :success
    context = response.parsed_body.fetch("inbox_context")
    assert_equal "01712345678", context.dig("customer", "phone")
    assert_equal "Dhaka", context.dig("customer", "address")
    assert_equal "catalogue", context.dig("order", "pricing")
    assert_equal "500.0", context.dig("order", "subtotal")
    assert_equal 2, context.dig("order", "items").size
    assert_not context.fetch("order").key?("delivery_charge")
    assert_not context.fetch("order").key?("total")
  end

  test "recorded order panel preserves historical prices rather than current catalogue prices" do
    conversation = @business.conversations.create!(channel: "facebook", external_customer_id: "history-buyer")
    product = @business.products.create!(name: "Shirt", price: 100, stock_quantity: 20)
    pending = conversation.create_pending_order!(product: product, quantity: 1, customer_name: "Buyer")
    order = conversation.orders.create!(business: @business, pending_order: pending, number: "INBOX-1",
      customer_name: "Buyer", phone: "01712345678", address: "Dhaka", subtotal: 100,
      delivery_charge: 70, total: 170, confirmed_at: Time.current)
    order.order_items.create!(product: product, product_name: "Original Shirt", quantity: 1, unit_price: 100, total: 100)
    product.update!(price: 999)

    get api_conversation_path(conversation), headers: @headers

    assert_response :success
    context = response.parsed_body.fetch("inbox_context")
    assert_equal "recorded", context.dig("order", "pricing")
    assert_equal "170.0", context.dig("order", "total")
    assert_equal "Original Shirt", context.dig("order", "items", 0, "product_name")
    assert_equal "100.0", context.dig("order", "items", 0, "unit_price")
    assert_equal 1, context.fetch("recorded_order_count")
  end

  test "other business conversations cannot expose context" do
    other = Business.create!(name: "Other", slug: "other-inbox")
    conversation = other.conversations.create!(channel: "facebook", external_customer_id: "private-buyer")

    get api_conversation_path(conversation), headers: @headers

    assert_response :not_found
    assert_not response.parsed_body.key?("inbox_context")
  end

  test "context history is bounded and excludes arbitrary conversation state" do
    conversation = @business.conversations.create!(channel: "facebook", external_customer_id: "many-orders",
      conversation_state: { private_secret: "do-not-expose" })
    (ConversationInboxContext::RECENT_ORDER_LIMIT + 1).times do |index|
      pending = conversation.create_pending_order!
      conversation.orders.create!(business: @business, pending_order: pending, number: "HISTORY-#{index}",
        customer_name: "Buyer", phone: "01712345678", address: "Dhaka", subtotal: 100, total: 100, confirmed_at: Time.current)
    end

    get api_conversation_path(conversation), headers: @headers

    assert_response :success
    assert_equal ConversationInboxContext::RECENT_ORDER_LIMIT, response.parsed_body.dig("inbox_context", "recent_orders").size
    assert_equal 6, response.parsed_body.dig("inbox_context", "recorded_order_count")
    assert_not_includes response.body, "do-not-expose"
  end
end
