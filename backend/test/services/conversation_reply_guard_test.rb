require "test_helper"

class ConversationReplyGuardTest < ActiveSupport::TestCase
  setup do
    @business = Business.create!(name: "Guard Shop", slug: "guard-shop")
    @product = @business.products.create!(name: "The Oud", price: 850, stock_quantity: 5)
    @other_product = @business.products.create!(name: "The Club", price: 390, stock_quantity: 5)
    @conversation = @business.conversations.create!(channel: "facebook", external_customer_id: SecureRandom.uuid)
    @order = @conversation.create_pending_order!(product: @product, quantity: 2, status: :collecting_name)
  end

  test "accepts a natural rewrite that preserves approved facts and question" do
    guard = build_guard(
      candidate: "Great—2 bottles of The Oud will be ৳1700. What name should I use?",
      fallback: "2 × The Oud, total ৳1700. What name should I put on the order?"
    )

    assert guard.valid?
  end

  test "rejects an invented price" do
    guard = build_guard(
      candidate: "The Oud is only ৳1200 today. What name should I use?",
      fallback: "2 × The Oud, total ৳1700. What name should I put on the order?"
    )

    assert_not guard.valid?
  end

  test "rejects an unapproved product and commercial promise" do
    product_guard = build_guard(candidate: "The Club is better. What name should I use?", fallback: "The Oud is selected. What name should I use?")
    claim_guard = build_guard(candidate: "Guaranteed free delivery. What name should I use?", fallback: "What name should I use?")

    assert_not product_guard.valid?
    assert_not claim_guard.valid?
  end

  test "accepts facts returned by an approved tool" do
    guard = build_guard(
      candidate: "The Oud 30 ML is ৳850.",
      fallback: "Here are the available details.",
      evidence: [ { "product_name" => "The Oud", "variant_name" => "30 ML", "price" => "850.0" } ]
    )

    assert guard.valid?
  end

  test "rejects an exact recent bot repetition" do
    guard = build_guard(
      candidate: "The Oud is selected. What name should I use?",
      fallback: "The Oud is selected. What name should I use?",
      recent: [ "The Oud is selected. What name should I use?" ]
    )

    assert_not guard.valid?
  end

  test "rejects a different checkout question even when it ends in a question mark" do
    assert_not build_guard(candidate: "The Oud is selected. What is your phone number?",
      fallback: "The Oud is selected. What name should I use?").valid?
  end

  test "retains negative product limitations instead of reversing them" do
    fallback = "The Oud is selected. Warranty is not verified. What name should I use?"
    assert_not build_guard(candidate: "The Oud is selected. Warranty is verified. What name should I use?", fallback: fallback).valid?
    assert build_guard(candidate: "The Oud is selected. Warranty is not verified. What name shall I use?", fallback: fallback).valid?
  end

  test "retains dependency and exclusivity constraints" do
    fallback = "The Oud is selected. Location depends on nearby devices. Pair with one ecosystem at a time."
    assert_not build_guard(candidate: "The Oud is selected. Location is always live.", fallback: fallback).valid?
  end

  test "ambiguous koto price question cannot replace a quantity question" do
    plan = Struct.new(:facts, :pending_question, :question_contract).new({}, "quantity", { "field" => "quantity" })
    guard = ConversationReplyGuard.new(candidate: "The Oud-er dam koto?", fallback: "The Oud-er koyta niben?",
      pending_order: @order, response_plan: plan)
    assert_not guard.valid?
  end

  private

  def build_guard(candidate:, fallback:, evidence: [], recent: [])
    plan = Struct.new(:facts, :pending_question).new(
      { "product_name" => "The Oud", "quantity" => 2, "total_price" => "1700.0" },
      fallback.include?("?") ? "customer_name" : nil
    )
    ConversationReplyGuard.new(
      candidate: candidate,
      fallback: fallback,
      pending_order: @order,
      response_plan: plan,
      tool_evidence: evidence,
      recent_replies: recent
    )
  end
end
