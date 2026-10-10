require "test_helper"

class Api::CommercePlatformTest < ActionDispatch::IntegrationTest
  setup do
    @business = create_business("alpha")
    @other_business = create_business("beta")
    @token = create_user(@business, "owner@alpha.test").first
    @other_token = create_user(@other_business, "owner@beta.test").first
  end

  test "dashboard endpoints require authentication" do
    get api_orders_path

    assert_response :unauthorized
  end

  test "products are strictly isolated by authenticated business" do
    own_product = @business.products.create!(name: "Alpha Product", price: 100, stock_quantity: 5)
    @other_business.products.create!(name: "Beta Product", price: 200, stock_quantity: 5)

    get api_products_path, headers: authorization(@token)

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [ own_product.id ], body.map { |product| product["id"] }
  end

  test "confirmed conversational order becomes a durable dashboard order" do
    product = @business.products.create!(name: "Alpha Product", price: 100, stock_quantity: 5)
    conversation = @business.conversations.create!(channel: "facebook", external_customer_id: "buyer-1")
    conversation.create_pending_order!(
      product: product, quantity: 2, customer_name: "Buyer", phone: "01712345678",
      address: "Dhaka", status: :awaiting_confirmation
    )

    result = CustomerMessageRecorder.new(
      business: @business, channel: "facebook", external_customer_id: "buyer-1", content: "confirm"
    ).record

    order = @business.orders.sole
    assert_equal :confirmed, result.outcome
    assert_equal "confirmed", order.status
    assert_equal 200.to_d, order.total
    assert_equal "Alpha Product", order.order_items.sole.product_name
    assert_equal 2, order.order_items.sole.quantity
  end

  test "order export contains only the current business orders" do
    create_order(@business, number: "ORD-ALPHA")
    create_order(@other_business, number: "ORD-BETA")

    get export_api_orders_path, headers: authorization(@token)

    assert_response :success
    assert_includes response.body, "ORD-ALPHA"
    assert_not_includes response.body, "ORD-BETA"
    assert_equal "text/csv", response.media_type
  end

  test "human takeover pauses automated replies and permits seller replies" do
    conversation = @business.conversations.create!(channel: "instagram", external_customer_id: "buyer-1")
    conversation.create_pending_order!

    post handover_api_conversation_path(conversation), headers: authorization(@token)
    assert_response :success
    assert_equal "seller_takeover", JSON.parse(response.body).dig("handover_summary", "reason")

    result = CustomerMessageRecorder.new(
      business: @business, channel: "instagram", external_customer_id: "buyer-1", content: "hello?"
    ).record
    assert_nil result.bot_reply
    assert_equal :awaiting_human, result.outcome

    post reply_api_conversation_path(conversation), params: { content: "A seller is here to help." },
      headers: authorization(@token), as: :json
    assert_response :created
    assert_equal "A seller is here to help.", conversation.messages.seller.sole.content
  end

  test "seller can review a conversation and record feedback" do
    conversation = @business.conversations.create!(channel: "facebook", external_customer_id: "review-buyer")
    message = conversation.messages.create!(sender_type: :customer, content: "show me something", metadata: {
      "classification_feedback" => { "predicted_intent" => "list_products" }
    })

    post review_api_conversation_path(conversation), params: {
      label: "confusing", notes: "Repeated question", message_id: message.id, corrected_intent: "product_search"
    },
      headers: authorization(@token), as: :json
    assert_response :success
    assert_equal "confusing", JSON.parse(response.body).dig("quality", "review", "label")
    assert_equal "product_search", message.reload.metadata.dig("classification_feedback", "corrected_intent")

    post feedback_api_conversation_path(conversation), params: { rating: "unhelpful" },
      headers: authorization(@token), as: :json
    assert_response :success
    assert_equal "unhelpful", JSON.parse(response.body).dig("quality", "customer_feedback", "rating")
  end

  test "seller cannot attach an invalid intent correction" do
    conversation = @business.conversations.create!(channel: "facebook", external_customer_id: "invalid-review")
    message = conversation.messages.create!(sender_type: :customer, content: "show me something")

    post review_api_conversation_path(conversation), params: {
      label: "incorrect_reply", message_id: message.id, corrected_intent: "invented_intent"
    }, headers: authorization(@token), as: :json

    assert_response :unprocessable_entity
    assert_equal "Invalid corrected intent", JSON.parse(response.body).fetch("error")
  end

  test "conversation quality endpoints are tenant isolated" do
    conversation = @other_business.conversations.create!(channel: "facebook", external_customer_id: "other-buyer")

    post review_api_conversation_path(conversation), params: { label: "successful" },
      headers: authorization(@token), as: :json

    assert_response :not_found
  end

  test "manual delivery integration submits an order without an external charge" do
    order = create_order(@business, number: "ORD-DELIVERY")
    integration = @business.create_delivery_integration!(provider: "manual", active: true)

    assert_enqueued_with(job: SubmitDeliveryJob) do
      post submit_delivery_api_order_path(order), headers: authorization(@token)
    end
    assert_response :accepted

    perform_enqueued_jobs
    assert_equal "submitted", order.reload.status
    assert_equal "submitted", order.delivery_submissions.sole.status
    assert_equal integration, order.delivery_submissions.sole.delivery_integration
  end

  test "analytics reports conversion and repeat customers per business" do
    first_conversation = @business.conversations.create!(channel: "facebook", external_customer_id: "repeat-buyer")
    second_conversation = @business.conversations.create!(channel: "instagram", external_customer_id: "visitor")
    create_order(@business, number: "ORD-1", conversation: first_conversation)
    create_order(@business, number: "ORD-2", conversation: first_conversation)

    get api_analytics_path, headers: authorization(@token)

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 2, body["conversations"]
    assert_equal 2, body["confirmed_orders"]
    assert_equal 1, body["repeat_customers"]
    assert_equal 50.0, body["conversation_to_order_rate"]
    assert_equal 100.0, body["repeat_customer_rate"]
    assert second_conversation.persisted?
  end

  test "analytics accepts legacy single handover summaries" do
    conversation = @business.conversations.create!(channel: "facebook", external_customer_id: "legacy-handover")
    conversation.update!(conversation_state: {
      "handover_summary" => { "reason" => "seller_takeover", "created_at" => 2.minutes.ago.iso8601 }
    })

    get api_analytics_path, headers: authorization(@token)

    assert_response :success
    assert_equal 1, JSON.parse(response.body).dig("handovers", "total")
  end

  test "analytics aggregates conversation repair and abandonment telemetry" do
    conversation = @business.conversations.create!(
      channel: "facebook", external_customer_id: "abandoned-buyer", status: :closed
    )
    conversation.create_pending_order!(status: :collecting_address)
    %w[invalid_phone order_updated clarification_needed].each do |outcome|
      conversation.messages.create!(sender_type: :customer, content: outcome, metadata: {
        "conversation_intelligence" => {
          "outcome" => outcome, "needs_clarification" => outcome == "clarification_needed"
        }
      })
    end

    get api_analytics_path, headers: authorization(@token)

    assert_response :success
    quality = JSON.parse(response.body).fetch("conversation_quality")
    assert_equal 33.33, quality.fetch("clarification_rate")
    assert_equal 33.33, quality.fetch("correction_rate")
    assert_equal 66.67, quality.fetch("repair_rate")
    assert_equal({ "collecting_address" => 1 }, quality.fetch("abandoned_checkout_stages"))
  end

  private

  def create_business(slug)
    Business.create!(name: slug.titleize, slug: slug, category: "retail")
  end

  def create_user(business, email)
    token, digest = User.issue_token
    user = business.users.create!(name: "Owner", email: email, role: "owner", api_token_digest: digest)
    [ token, user ]
  end

  def authorization(token)
    { "Authorization" => "Bearer #{token}" }
  end

  def create_order(business, number:, conversation: nil)
    conversation ||= business.conversations.create!(channel: "facebook", external_customer_id: SecureRandom.uuid)
    product = business.products.create!(name: "Product #{number}", price: 100, stock_quantity: 10)
    pending_order = conversation.create_pending_order!(
      product: product, quantity: 1, customer_name: "Buyer", phone: "01712345678",
      address: "Dhaka", status: :confirmed
    )
    order = business.orders.create!(
      conversation: conversation, pending_order: pending_order, number: number, customer_name: "Buyer",
      phone: "01712345678", address: "Dhaka", subtotal: 100, total: 100, confirmed_at: Time.current
    )
    order.order_items.create!(product: product, product_name: product.name, quantity: 1, unit_price: 100, total: 100)
    order
  end
end
