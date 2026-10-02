require "test_helper"

class ConversationPlannerQualityBenchmarkTest < ActiveSupport::TestCase
  setup do
    @business = Business.create!(name: "Benchmark Shop", slug: "benchmark-shop")
    @product = @business.products.create!(name: "The Oud", price: 850, stock_quantity: 10)
    @business.create_business_policy!(
      delivery_charges: "Dhaka delivery is ৳80.",
      cash_on_delivery: "Cash on delivery is available."
    )
  end

  test "benchmarks product selection and checkout progression" do
    result = record("I want The Oud")

    assert_equal :product_selected, result.outcome
    assert_equal "collect_quantity", result.response_plan.goal
    assert_equal "quantity", result.response_plan.pending_question
    assert_equal "The Oud", result.response_plan.facts.fetch("product_name")
    assert_predicate result.pending_order, :collecting_quantity?
  end

  test "benchmarks an informational interruption without losing checkout state" do
    conversation = create_conversation
    conversation.create_pending_order!(product: @product, quantity: 2, status: :collecting_name)

    result = record("delivery charge koto?", customer_id: conversation.external_customer_id)

    assert_equal :delivery_charge_requested, result.outcome
    assert_equal "answer_and_resume_order", result.response_plan.goal
    assert_equal "customer_name", result.response_plan.pending_question
    assert_predicate result.pending_order, :collecting_name?
    assert_includes result.bot_reply.content, "Dhaka delivery is ৳80."
  end

  test "benchmarks stable Banglish language through a short follow-up" do
    conversation = create_conversation
    conversation.update!(conversation_state: { "preferred_language" => "banglish" })
    conversation.create_pending_order!(status: :collecting_product)

    result = record("oud", customer_id: conversation.external_customer_id)

    assert_equal "banglish", result.response_plan.language
    assert_equal "quantity", result.response_plan.pending_question
    assert_equal "The Oud", result.response_plan.facts.fetch("product_name")
  end

  test "benchmarks an atomic confirmed-order correction" do
    conversation = create_conversation
    conversation.create_pending_order!(
      product: @product, quantity: 1, customer_name: "Anik", phone: "01712345678",
      address: "Dhaka", status: :confirmed
    )

    result = record("actually make it two", customer_id: conversation.external_customer_id)

    assert_equal :confirmed_order_updated, result.outcome
    assert_equal 2, result.pending_order.reload.quantity
    assert_predicate result.pending_order, :awaiting_confirmation?
    assert_equal "confirmation", result.response_plan.pending_question
  end

  test "benchmarks explicit seller handover" do
    result = record("I need to speak with a person")

    assert_equal :human_handover_started, result.outcome
    assert result.response_plan.handover_required
    assert_equal "handover_to_seller", result.response_plan.goal
    assert_predicate result.conversation, :handed_over?
  end

  private

  def record(content, customer_id: SecureRandom.uuid)
    CustomerMessageRecorder.new(
      channel: "facebook",
      external_customer_id: customer_id,
      content: content,
      business: @business
    ).record
  end

  def create_conversation
    @business.conversations.create!(channel: "facebook", external_customer_id: SecureRandom.uuid)
  end
end
