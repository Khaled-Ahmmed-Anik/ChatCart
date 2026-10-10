require "test_helper"

class GuidedSalesQualityScenariosTest < ActiveSupport::TestCase
  setup do
    @business = Business.create!(name: "Scenario Shop", slug: "scenario-#{SecureRandom.hex(4)}")
    @fresh = @business.products.create!(
      name: "Office Fresh", price: 700, stock_quantity: 8, short_description: "A clean daily fragrance.",
      product_attributes: { scent_families: [ "fresh" ], occasions: [ "office" ] }
    )
    @oud = @business.products.create!(
      name: "Wedding Oud", price: 1_200, stock_quantity: 6, short_description: "A rich oud for celebrations.",
      product_attributes: { scent_families: [ "oud" ], occasions: [ "wedding" ], projection: "strong" }
    )
    @conversation = @business.conversations.create!(channel: "facebook", external_customer_id: SecureRandom.uuid)
    @order = @conversation.pending_orders.create!(status: :collecting_product)
  end

  test "asks one narrowing question for a request with only one preference" do
    result = ProductRecommendationService.new(
      business: @business, message: "fresh kichu chai", preferences: { scent_families: [ "fresh" ] }
    ).call

    assert_includes result.clarification_question, "daily use, office, an occasion, or a gift"
  end

  test "recommends immediately and explains a grounded fit for a rich request" do
    @conversation.update!(conversation_state: {
      "shopping_preferences" => { "scent_families" => [ "oud" ], "occasions" => [ "wedding" ] }
    })
    message = @conversation.messages.create!(sender_type: :customer, content: "strong oud for wedding")

    reply = BotReplyGenerator.new(
      pending_order: @order, customer_message: message, outcome: :product_recommendation_requested
    ).content

    assert_includes reply, "Wedding Oud"
    assert_includes reply, "Why it fits: matches your oud preference and suited to wedding"
    offered = @conversation.reload.conversation_state.fetch("last_offered_options")
    assert_equal "products", offered["kind"]
    assert_equal @oud.id, offered["options"].first["id"]
  end

  test "never invents a discount when no policy is configured" do
    message = @conversation.messages.create!(sender_type: :customer, content: "best price or discount?")

    reply = BotReplyGenerator.new(pending_order: @order, customer_message: message, outcome: :discount_requested).content

    assert_includes reply, "don’t have an approved discount to promise"
  end

  test "uses the business authenticity statement verbatim" do
    @business.create_business_policy!(authenticity_statement: "Every sealed item includes our supplier verification card.")
    message = @conversation.messages.create!(sender_type: :customer, content: "is it original?")

    reply = BotReplyGenerator.new(pending_order: @order, customer_message: message,
      outcome: :authenticity_requested).content

    assert_equal "Every sealed item includes our supplier verification card.", reply
  end

  test "uses explicit recovery choices on the second misunderstanding" do
    2.times do
      @conversation.messages.create!(sender_type: :customer, content: "oi ta", metadata: {
        "conversation_intelligence" => { "needs_clarification" => true }
      })
    end

    reply = BotReplyGenerator.new(pending_order: @order, outcome: :clarification_needed).content

    assert_includes reply, "Reply with a number"
    assert_includes reply, "4. Talk to the seller"
  end
end
