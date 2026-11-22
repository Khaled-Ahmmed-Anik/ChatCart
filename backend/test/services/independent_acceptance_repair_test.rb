require "test_helper"

class IndependentAcceptanceRepairTest < ActiveSupport::TestCase
  setup do
    @business = Business.create!(name: "Acceptance Repair", slug: "acceptance-repair", category: "retail")
    @buds = @business.products.create!(name: "Hoco EQ34 Plus", aliases: [ "earbuds", "ইয়ারবাড" ], category: "earbuds", price: 729, stock_quantity: 10,
      product_attributes: { catalogue_facts: { warranty: "6 months seller warranty" } })
    @charger = @business.products.create!(name: "Anker Nano Charger", aliases: [ "charger", "চার্জার" ], category: "charger", price: 1849, stock_quantity: 10)
    @shirt = @business.products.create!(name: "Cotton Shirt", category: "clothing", price: 550, stock_quantity: 10)
    @blue = @shirt.product_variants.create!(name: "Blue L", size: "L", price: 550, stock_quantity: 10)
    @shirt.product_variants.create!(name: "Red M", size: "M", price: 600, stock_quantity: 10)
    @business.policy.update!(delivery_charges: "Delivery charge: ৳80", delivery_time: "2–3 days", cash_on_delivery: "Cash on delivery is available")
    @customer = SecureRandom.uuid
  end

  test "Bengali multi-product quantities remain attached to their own products" do
    order = record("ইয়ারবাড ২টা আর চার্জার ১টা চাই").pending_order
    assert_equal({ @buds.id => 2, @charger.id => 1 }, quantities(order))
    result = record("সব মিলিয়ে কত টাকা?")
    assert_includes result.bot_reply.content, "3307"
    assert_equal({ @buds.id => 2, @charger.id => 1 }, quantities(order))
  end

  test "quantity-first Bengali units cannot be assigned to the next product" do
    order = record("২টা ইয়ারবাড আর ১টা চার্জার চাই").pending_order
    assert_equal({ @buds.id => 2, @charger.id => 1 }, quantities(order))
  end

  test "polite and Bengali removal target the cart instead of shortlist or pause" do
    [ "Please remove the charger from my order.", "চার্জারটা বাদ দিন" ].each do |text|
      @customer = SecureRandom.uuid
      order = record("add earbuds 2 pieces and charger 1 piece").pending_order
      result = record(text)
      assert_equal :cart_updated, result.outcome
      assert_equal({ @buds.id => 2 }, quantities(order))
    end
  end

  test "Bengali quantity correction changes only the named line" do
    order = record("add earbuds 2 pieces and charger 1 piece").pending_order
    record("ইয়ারবাড ৩টা করুন")
    assert_equal({ @buds.id => 3, @charger.id => 1 }, quantities(order))
  end

  test "Bengali unknown addition cannot partially apply a cart change" do
    order = record("earbuds 1 piece den").pending_order
    result = record("Mystery Adapter ১টা আর চার্জার ১টা যোগ করুন")
    assert_equal :cart_needs_details, result.outcome
    assert_equal({ @buds.id => 1 }, quantities(order))
    assert_nil order.order
  end

  test "plural product name retains its requested variant and quantity" do
    order = record("Please order two Cotton Shirts in Blue L.").pending_order
    assert_equal @shirt.id, order.product_id
    assert_equal @blue.id, order.product_variant_id
    assert_equal 2, order.quantity
  end

  test "negated Bengali cart commands do not add or remove items" do
    order = record("add earbuds 2 pieces and charger 1 piece").pending_order
    [ "চার্জারটা বাদ দেবেন না", "ইয়ারবাড ৩টা যোগ করবেন না" ].each do |text|
      record(text)
      assert_equal({ @buds.id => 2, @charger.id => 1 }, quantities(order))
    end
  end

  test "product warranty and business delivery are both answered without changing the cart" do
    [ "What is the warranty and how much is delivery?", "warranty koto din ar delivery charge koto?",
      "ওয়ারেন্টি কতদিন আর ডেলিভারি চার্জ কত?" ].each do |text|
      @customer = SecureRandom.uuid
      order = record("earbuds 2 pieces den").pending_order
      reply = record(text).bot_reply.content
      assert_includes reply, "6 months"
      assert_includes reply, "80"
      assert_equal({ @buds.id => 2 }, quantities(order))
    end
  end

  test "multi-item warranty question asks which product instead of choosing the current line" do
    order = record("add earbuds 2 pieces and charger 1 piece").pending_order
    reply = record("What is the warranty and how much is delivery?").bot_reply.content
    assert_includes reply, "80"
    assert_includes reply, "Which product"
    assert_not_includes reply, "6 months"
    assert_equal({ @buds.id => 2, @charger.id => 1 }, quantities(order))
  end

  test "natural payment and delivery-time questions use configured policy" do
    record("earbuds 1 piece den")
    assert_includes record("Can I pay when I receive it?").bot_reply.content, "Cash on delivery"
    assert_includes record("How long does delivery take?").bot_reply.content, "2–3 days"
  end

  test "Bengali ordinal selects only a currently displayed option" do
    result = record("show all products")
    second = result.conversation.reload.conversation_state.dig("last_offered_options", "options", 1, "id")
    result = record("দ্বিতীয়টা নেব")
    assert_equal second, result.pending_order.product_id
    assert_not_predicate result.pending_order, :confirmed?
  end

  test "Bengali contact digits are validated and stored in canonical form" do
    record("earbuds 1 piece den")
    record("নাদিয়া রহমান")
    result = record("০১৭০০০০০০০০")
    assert_predicate result.pending_order, :collecting_address?
    assert_equal "01700000000", result.pending_order.phone
    result = record("বাড়ি ১২, রোড ৪, ঢাকা")
    assert_predicate result.pending_order, :awaiting_confirmation?
    assert_equal :confirmed, record("নিশ্চিত করুন").outcome
  end

  test "Bengali checkout keeps native copy through a short name and numeric reply" do
    record("ইয়ারবাড ২টা আর চার্জার ১টা চাই")
    named = record("নাদিয়া রহমান")
    assert_includes named.bot_reply.content, "ফোন নম্বর"
    phone = record("০১৭০০০০০০০০")
    assert_includes phone.bot_reply.content, "ঠিকানা"
    summary = record("বাড়ি ১২, রোড ৪, ঢাকা")
    assert_includes summary.bot_reply.content, "আপনার অর্ডারের বিবরণ"
    assert_includes summary.bot_reply.content, "ডেলিভারি চার্জ যোগ হয়নি"
    assert_equal "bengali", summary.conversation.reload.conversation_state["preferred_language"]
  end

  test "an explicitly requested English language is respected for a Bengali name" do
    state = { "preferred_language" => "english", "language_explicit" => true }
    assert_equal "english", ConversationLanguagePreference.choose("নাদিয়া রহমান", state)
    assert_equal "bengali", ConversationLanguagePreference.choose("নাদিয়া রহমান", state.except("language_explicit"))
  end

  test "Bengali phone digits are redacted from classifier prompts" do
    message = Struct.new(:content).new("ফোন ০১৭০০০০০০০০")
    classifier = AiIntentClassifier.new(message: message, pending_order: nil, recent_messages: [], api_key: nil)
    sanitized = classifier.send(:sanitize, message.content)
    assert_includes sanitized, "[PHONE]"
    assert_not_includes sanitized, "০১৭০০০০০০০০"
  end

  test "localized confirmed details show final status without asking for confirmation again" do
    record("earbuds 1 piece den")
    record("Nadia Rahman")
    record("01700000000")
    record("Test address, Dhaka")
    record("confirm")
    result = record("amar order details ta ki silo?")
    assert_includes result.bot_reply.content, "confirmed order details"
    assert_includes result.bot_reply.content, "already confirmed"
    assert_not_includes result.bot_reply.content, "“confirm”"
    assert_equal 1, @business.orders.count
  end

  test "hypothetical purchases quote without changing any checkout details" do
    [ "What if I buy three earbuds instead?", "jodi earbuds tinta nibo?", "যদি ইয়ারবাড ৩টা নিই?" ].each do |question|
      @customer = SecureRandom.uuid
      order = record("add earbuds 1 piece and charger 1 piece").pending_order
      before = order.reload.attributes
      result = record(question)
      assert_equal({ @buds.id => 1, @charger.id => 1 }, quantities(order))
      assert_equal before, order.reload.attributes
      assert_equal 0, @business.orders.count
      assert_includes result.bot_reply.content, "2187"
    end
  end

  test "explicit set quantity after a side question changes only the named item" do
    order = record("add earbuds 1 piece and charger 1 piece").pending_order
    record("How much is shipping?")
    record("Set charger quantity to 2")
    assert_equal({ @buds.id => 1, @charger.id => 2 }, quantities(order))
    record("Do not set charger quantity to 3")
    assert_equal({ @buds.id => 1, @charger.id => 2 }, quantities(order))
  end

  test "general price inquiries cannot find a size inside another word" do
    @shirt.update!(aliases: [ "shirt" ])
    order = record("add earbuds 1 piece and charger 1 piece").pending_order
    result = record("shirt er dam koto bhai?")
    assert_includes result.bot_reply.content, "550"
    assert_includes result.bot_reply.content, "600"
    assert_equal({ @buds.id => 1, @charger.id => 1 }, quantities(order))
    result = record("shirt Blue L price?")
    assert_includes result.bot_reply.content, "550"
    assert_not_includes result.bot_reply.content, "600"
  end

  test "early policy routing answers return and delivery questions together" do
    @business.policy.update!(return_policy: "Returns within 7 days")
    [ "Can I return it and how long will delivery take?",
      "return kora jabe ar delivery kobe pabo?",
      "ফেরত দেওয়া যাবে আর ডেলিভারি কতদিন লাগবে?" ].each do |question|
      @customer = SecureRandom.uuid
      order = record("earbuds 1 piece den").pending_order
      result = record(question)
      assert_includes result.bot_reply.content, "7 days"
      assert_includes result.bot_reply.content, "2–3 days"
      assert_equal({ @buds.id => 1 }, quantities(order))
      assert_equal 0, @business.orders.count
    end
  end

  private

  def quantities(order)
    order.reload.line_items.to_h { |item| [ item.product_id, item.quantity ] }
  end

  def record(content)
    CustomerMessageRecorder.new(business: @business, channel: "facebook", external_customer_id: @customer, content: content).record
  end
end
