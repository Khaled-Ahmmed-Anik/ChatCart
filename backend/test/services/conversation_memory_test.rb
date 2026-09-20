require "test_helper"

class ConversationMemoryTest < ActiveSupport::TestCase
  test "remembers useful context without storing contact details in the AI context" do
    conversation = Conversation.create!(channel: "facebook", external_customer_id: SecureRandom.uuid)
    product = conversation.business.products.create!(name: "Fresh Musk", price: 750, stock_quantity: 10)
    order = conversation.create_pending_order!(
      product: product, quantity: 2, customer_name: "Khaled", phone: "01712345678",
      address: "Badda, Dhaka", status: :awaiting_confirmation
    )
    interpretation = AiIntentClassifier::Result.new(
      intent: "review_order", secondary_intents: [ "delivery_time" ], confidence: 0.95,
      entities: {}.with_indifferent_access, language: "banglish", sentiment: "neutral",
      needs_clarification: false, possible_intents: []
    )

    memory = ConversationMemory.new(conversation)
    memory.remember!(interpretation: interpretation, pending_order: order, outcome: :order_details_requested)
    context = memory.context

    assert_equal "Fresh Musk", context[:last_referenced_product]
    assert_equal "review_order", context[:intent_history].last["intent"]
    assert_equal true, context.dig(:customer_profile, "has_phone")
    assert_not_includes context.to_json, "01712345678"
    assert_not_includes context.to_json, "Badda"
  end
end
