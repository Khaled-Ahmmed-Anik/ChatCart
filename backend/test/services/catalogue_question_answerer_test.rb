require "test_helper"

class CatalogueQuestionAnswererTest < ActiveSupport::TestCase
  setup do
    @business = Business.create!(name: "Tech", slug: "grounded-tech", category: "electronics")
    @product = @business.products.create!(name: "Hoco EQ34 Plus", category: "earbuds", price: 729, stock_quantity: 100,
      description: "Up to 7 hours playback; up to 6 hours with ANC on.\nANC and ENC support calls.\nCharging Cable: Confirm whether included in your package.")
    @conversation = @business.conversations.create!(channel: "facebook", external_customer_id: "grounded")
  end

  test "answers catalogue facts without starting checkout" do
    CustomerMessageRecorder.new(business: @business, channel: "facebook", external_customer_id: "grounded", content: "need earbuds").record
    result = CustomerMessageRecorder.new(business: @business, channel: "facebook", external_customer_id: "grounded",
      content: "Hoco EQ34 Plus er battery koto khon chole? ANC ache?").record
    assert_includes result.bot_reply.content, "7 hours"
    assert_includes result.bot_reply.content, "6 hours"
    assert_includes result.bot_reply.content, "ANC"
    assert_nil result.pending_order.reload.product_id
    assert_nil result.pending_order.quantity
  end

  test "unknown package inclusion and warranty are explicit without promises" do
    reply = CatalogueQuestionAnswerer.new(product: @product, text: "Cable included and warranty?").content
    assert_includes reply, "Cable inclusion is not verified"
    assert_includes reply, "Warranty is not verified"
    assert_not_includes reply, "Package contents is not verified"
  end

  test "cable performance evidence does not verify package inclusion" do
    @product.update!(description: "Charging Cable: Confirm whether included in your package.\nCharging speed depends on device and cable compatibility.")
    reply = CatalogueQuestionAnswerer.new(product: @product, text: "Cable included and warranty?").content
    assert_includes reply, "Cable inclusion is not verified"
    assert_includes reply, "Warranty is not verified"
  end

  test "shared evidence appears only once across requested topics" do
    @product.update!(description: "Cable included in the package.\nCharging speed depends on device and cable compatibility.")
    reply = CatalogueQuestionAnswerer.new(product: @product, text: "Cable included? What is the charging speed? Package contents?").content
    assert_equal 1, reply.scan("Cable included in the package.").size
    assert_equal 1, reply.scan("Charging speed depends on device and cable compatibility.").size
  end

  test "negative cable inclusion and seller declared facts are preserved" do
    @product.update!(description: "Cable is not included in the package.")
    reply = CatalogueQuestionAnswerer.new(product: @product, text: "Cable included?").content
    assert_includes reply, "Cable is not included"
    @product.update!(product_attributes: { catalogue_facts: { cable: "USB-C cable supplied separately; not included." } })
    reply = CatalogueQuestionAnswerer.new(product: @product, text: "Cable included?").content
    assert_includes reply, "supplied separately; not included"
    assert_not_includes reply, "Cable inclusion is not verified"
  end

  test "tracking limitations are retained instead of a GPS promise" do
    @product.update!(description: "Apple and Google networks supported.\nNot a standalone real-time GPS tracker.\nLocation updates depend on participating devices.\nPair with one ecosystem at a time.")
    reply = CatalogueQuestionAnswerer.new(product: @product, text: "Is this live GPS for my car?").content
    assert_includes reply, "Not a standalone real-time GPS"
    assert_includes reply, "depend on participating"
  end

  test "SIM and battery facts are not payment or delivery policy questions" do
    assert_empty ConversationActionPlanner.policy_information_outcomes("Can I insert a SIM card into it?")
    assert_empty ConversationActionPlanner.policy_information_outcomes("Battery koto din chole?")
    assert_includes ConversationActionPlanner.policy_information_outcomes("delivery koto din lagbe?"), :delivery_time_requested
  end

  test "every second is a tracking interval rather than the second offered product" do
    @conversation.update!(conversation_state: { "last_offered_options" => { "kind" => "products", "options" => [ { "id" => @product.id } ] } })
    @product.update!(description: "Not a standalone real-time GPS tracker. Location updates depend on participating devices.")
    result = CustomerMessageRecorder.new(business: @business, channel: "facebook", external_customer_id: "grounded",
      content: "Can it track a car live every second?").record
    assert_includes result.bot_reply.content, "Not a standalone"
    refute_equal :offered_reference_clarification, result.outcome
  end
end
