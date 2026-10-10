require "test_helper"

class ConversationContextRecoveryTest < ActiveSupport::TestCase
  setup do
    @business = Business.create!(name: "Recovery Shop", slug: "recovery-shop", category: "retail")
    @combo = @business.products.create!(name: "Combo for Her", price: 1_050, stock_quantity: 100, product_type: "fixed_combo")
    @combo.product_variants.create!(name: "10 ML", size: "10 ML", price: 1_050, stock_quantity: 100, active: true)
    %w[Fresh Floral Woody].each_with_index do |style, index|
      @business.products.create!(
        name: "#{style} Choice", price: 400 + (index * 50), stock_quantity: 10,
        short_description: "A #{style.downcase} everyday fragrance",
        product_attributes: { scent_families: [ style.downcase ], occasions: [ "daily" ] }
      )
    end
    @customer_id = "context-recovery-customer"
  end

  test "paused product context stays quiet during small talk and a decline" do
    conversation = @business.conversations.create!(channel: "facebook", external_customer_id: @customer_id)
    conversation.create_pending_order!(product: @combo, status: :collecting_variant)

    paused = record("nibo na")
    assert_equal :order_paused, paused.outcome
    assert paused.conversation.reload.conversation_state["order_context_paused"]
    assert_not_includes paused.bot_reply.content, "size"

    wellbeing = record("ki khobor")
    assert_equal :wellbeing, wellbeing.outcome
    assert_not_includes wellbeing.bot_reply.content, "Combo for Her"
    assert_not_includes wellbeing.bot_reply.content.downcase, "size"

    decline = record("na")
    assert_equal :order_paused, decline.outcome
    assert_not_includes decline.bot_reply.content, "Combo for Her"
  end

  test "explains the previous question instead of dumping the catalogue" do
    conversation = @business.conversations.create!(channel: "facebook", external_customer_id: @customer_id)
    conversation.create_pending_order!(product: @combo, status: :collecting_variant)
    conversation.messages.create!(sender_type: :bot, content: "Apnar scent, price, naki onno kichu pochondo hoyni?")

    result = record("mane ki")

    assert_equal :previous_question_explained, result.outcome
    assert_includes result.bot_reply.content, "scent"
    assert_not_includes result.bot_reply.content, "Fresh Choice"
  end

  test "two different fragrances advances discovery without repeating single or combo" do
    first = record("2 ta suggest koren")
    assert_equal :product_recommendation_requested, first.outcome
    assert_match(/single perfume|combo/i, first.bot_reply.content)

    second = record("2 ta nite chai different fragrance")

    assert_equal :product_recommendation_requested, second.outcome
    assert_equal 2, second.conversation.reload.conversation_state.dig("shopping_preferences", "recommendation_count")
    assert_equal "single", second.conversation.conversation_state.dig("shopping_preferences", "format")
    assert_match(/scent styles|fresh|sweet|woody/i, second.bot_reply.content)
    assert_no_match(/single perfume.*combo/i, second.bot_reply.content)
  end

  private

  def record(content)
    CustomerMessageRecorder.new(
      business: @business,
      channel: "facebook",
      external_customer_id: @customer_id,
      content: content
    ).record
  end
end
