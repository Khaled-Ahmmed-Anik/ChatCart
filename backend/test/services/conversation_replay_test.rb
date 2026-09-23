require "test_helper"

class ConversationReplayTest < ActiveSupport::TestCase
  test "replays a multi-intent Banglish purchase without losing the active order" do
    business = Business.create!(name: "Replay Shop", slug: "replay-shop-multi")
    product = business.products.create!(name: "The Oud", price: 0, stock_quantity: 0)
    variant = product.product_variants.create!(name: "30 ML", size: "30 ML", price: 850, stock_quantity: 8)
    conversation = business.conversations.create!(channel: "facebook", external_customer_id: SecureRandom.uuid)
    order = conversation.create_pending_order!(status: :collecting_product)

    first = replay(order, "The Oud 30ml two bottles, delivery charge koto?")
    assert_equal :multiple_details_collected, first.outcome
    assert_equal [ :delivery_charge_requested ], first.secondary_outcomes
    assert_equal [ product.id, variant.id, 2, "collecting_name" ],
      order.reload.values_at(:product_id, :product_variant_id, :quantity, :status)

    side_question = replay(order, "COD ache?")
    assert_equal :cash_on_delivery_requested, side_question.outcome
    assert_predicate order.reload, :collecting_name?

    replay(order, "Anik, 01725126467, Middle Badda, Dhaka")
    assert_predicate order.reload, :awaiting_confirmation?
    assert_equal "Anik", order.customer_name
    assert_equal "01725126467", order.phone
    assert_equal "Middle Badda, Dhaka", order.address
  end

  test "replays a product correction as one atomic customer turn" do
    business = Business.create!(name: "Replay Shop", slug: "replay-shop-correction")
    oud = business.products.create!(name: "The Oud", price: 500, stock_quantity: 5)
    office = business.products.create!(name: "The Office", price: 0, stock_quantity: 0)
    variant = office.product_variants.create!(name: "10 ML", size: "10 ML", price: 350, stock_quantity: 5)
    conversation = business.conversations.create!(channel: "facebook", external_customer_id: SecureRandom.uuid)
    order = conversation.create_pending_order!(product: oud, status: :collecting_quantity)

    result = replay(order, "Not The Oud, give The Office 10ml two bottles")

    assert_equal :multiple_details_collected, result.outcome
    assert_equal [ office.id, variant.id, 2 ], order.reload.values_at(:product_id, :product_variant_id, :quantity)
  end

  private

  def replay(order, content)
    message = order.conversation.messages.create!(sender_type: :customer, content: content)
    interpretation = CompactIntentClassifier.new(message: message, pending_order: order).classify.interpretation
    ConversationMessageProcessor.new(
      message: message, pending_order: order, interpretation: interpretation
    ).tap(&:process)
  end
end
