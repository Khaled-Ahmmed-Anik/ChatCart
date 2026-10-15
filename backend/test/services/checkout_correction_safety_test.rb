require "test_helper"

class CheckoutCorrectionSafetyTest < ActiveSupport::TestCase
  setup do
    @business = Business.create!(name: "Correction Shop", slug: "correction-shop")
    @oud = @business.products.create!(name: "The Oud", price: 580, stock_quantity: 20)
    @club = @business.products.create!(name: "The Club", price: 530, stock_quantity: 20)
    [ @club, @oud ].each { |p| p.product_variants.create!(name: "15 ML", size: "15 ML", price: p.price, stock_quantity: 20) }
    @customer = SecureRandom.uuid
  end

  test "Banglish quantity correction cannot become a checkout name" do
    draft = record("The Oud 15 ml duita den").pending_order
    record("actually ekta koren")
    assert_equal 1, draft.reload.quantity
    assert_nil draft.customer_name
    assert_equal 580.to_d, draft.total_price
  end

  test "product negation wins over size matching and name extraction" do
    draft = record("The Club 15 ml ekta den").pending_order
    record("Club na, The Oud 15 ml den")
    assert_equal @oud, draft.reload.product
    assert_nil draft.customer_name
    assert_not_equal @club, draft.product
  end

  test "two turn address and phone edits preserve other checkout details" do
    draft = ready_draft
    assert_equal :checkout_edit_requested, record("address change korbo").outcome
    record("Test Address B, Dhaka")
    assert_equal "Test Address B, Dhaka", draft.reload.address
    record("phone number change korbo")
    record("01700000001")
    assert_equal "01700000001", draft.reload.phone
    assert_equal "Test Buyer", draft.customer_name
    assert_equal 1, draft.quantity
    assert_empty draft.conversation.reload.conversation_state.to_h.slice("checkout_edit")
  end

  test "a side question does not overwrite a pending address edit" do
    draft = ready_draft
    record("change address")
    record("delivery charge koto?")
    assert_equal "Test Address A", draft.reload.address
    record("Test Address B, Dhaka")
    assert_equal "Test Address B, Dhaka", draft.reload.address
  end

  test "submitted order cannot begin a detail edit" do
    draft = ready_draft
    draft.update!(status: :submitted_to_woocommerce)
    record("change address")
    assert_equal "Test Address A", draft.reload.address
    assert_nil draft.conversation.reload.conversation_state.to_h["checkout_edit"]
  end

  test "invalid replacement phone keeps the edit pending" do
    draft = ready_draft
    record("change phone")
    record("123")
    assert_equal "01700000000", draft.reload.phone
    assert_equal "phone", draft.conversation.reload.conversation_state.dig("checkout_edit", "field")
    record("01700000001")
    assert_equal "01700000001", draft.reload.phone
  end

  test "confirmed detail edits require review without updating the captured address" do
    draft = ready_draft
    record("confirm")
    captured = draft.reload.order
    original_address = captured.address
    record("change address")
    record("Test Address B, Dhaka")
    assert_predicate draft.reload, :awaiting_confirmation?
    assert_equal "revision_pending", captured.reload.status
    assert_equal original_address, captured.address
  end

  private

  def ready_draft
    record("The Oud 15 ml ekta den").pending_order.tap do |draft|
      draft.update!(customer_name: "Test Buyer", phone: "01700000000", address: "Test Address A", status: :awaiting_confirmation)
    end
  end

  def record(content)
    CustomerMessageRecorder.new(business: @business, channel: "facebook", external_customer_id: @customer, content: content).record
  end
end
