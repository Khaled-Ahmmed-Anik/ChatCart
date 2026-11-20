require "test_helper"

class CatalogueReferenceSafetyTest < ActiveSupport::TestCase
  setup do
    @business = Business.create!(name: "Tech", slug: "reference-tech", category: "electronics")
    @buds = @business.products.create!(name: "Pro 2", category: "earbuds", price: 599, stock_quantity: 5)
    @case = @business.products.create!(name: "AirPods Pro 2 Designer Protective Case", category: "earbuds accessories", price: 299, stock_quantity: 5)
    @hoco = @business.products.create!(name: "Hoco EQ34 Plus", category: "earbuds", price: 729, stock_quantity: 5)
    @conversation = @business.conversations.create!(channel: "facebook", external_customer_id: "reference")
  end

  test "accessory qualifier wins over short overlapping product name" do
    result = ProductResolutionService.new(business: @business, query: "AirPods Pro 2 er protective case chai").resolve
    assert_predicate result, :matched?
    assert_equal @case, result.product
    assert_equal [ "earbuds accessories" ], CatalogueCategoryResolver.call(business: @business, text: "not earbuds, protective cover please")
  end

  test "ordinal questions resolve the actual offered list without selecting an order" do
    @conversation.update!(conversation_state: { "last_offered_options" => { "kind" => "products", "options" => [ { "id" => @hoco.id }, { "id" => @buds.id } ] } })
    order = @conversation.create_pending_order!
    result = CustomerMessageRecorder.new(business: @business, channel: "facebook", external_customer_id: "reference",
      content: "The second one: what is its price?").record
    assert_includes result.bot_reply.content, "599"
    assert_nil order.reload.product_id
    assert_equal @buds.name, @conversation.reload.conversation_state["last_referenced_product"]
  end

  test "offered ids cannot resolve another business product" do
    other = Business.create!(name: "Other", slug: "reference-other")
    product = other.products.create!(name: "Other secret", price: 1, stock_quantity: 2)
    @conversation.update!(conversation_state: { "last_offered_options" => { "kind" => "products", "options" => [ { "id" => product.id } ] } })
    assert_nil CatalogueConversationReference.new(conversation: @conversation, text: "this one").product
  end

  test "comparison price question preserves offered products for a following brand reference" do
    @conversation.update!(conversation_state: { "last_offered_options" => { "kind" => "products", "options" => [ { "id" => @hoco.id }, { "id" => @buds.id } ] } })
    result = CustomerMessageRecorder.new(business: @business, channel: "facebook", external_customer_id: "reference",
      content: "Which one is cheaper and what is the difference in price?").record
    assert_includes result.bot_reply.content, "130"
    result = CustomerMessageRecorder.new(business: @business, channel: "facebook", external_customer_id: "reference",
      content: "I prefer the Hoco one. Remind me of its price.").record
    assert_includes result.bot_reply.content, "729"
    refute_includes result.bot_reply.content, "299"
  end

  test "out of range ordinal clarifies without replacing the actual offered list" do
    @conversation.update!(conversation_state: { "last_offered_options" => { "kind" => "products", "options" => [ { "id" => @hoco.id } ] } })
    result = CustomerMessageRecorder.new(business: @business, channel: "facebook", external_customer_id: "reference",
      content: "The second one: what is its price?").record
    assert_equal :offered_reference_clarification, result.outcome
    assert_equal [ @hoco.id ], @conversation.reload.conversation_state.dig("last_offered_options", "options").map { |option| option["id"] }
    refute_includes result.bot_reply.content, "299"
  end

  test "negative category is not returned as the requested category" do
    assert_empty CatalogueCategoryResolver.call(business: @business, text: "not earbuds")
  end

  test "negative protective case requests exclude accessories without excluding earbuds" do
    result = ProductResolutionService.new(business: @business, query: "No protective cases please; only actual earbuds.").resolve
    refute_equal @case, result.product
    refute_includes CatalogueCategoryResolver.call(business: @business, text: "Cover chai na, sudhu earbuds"), "earbuds accessories"
  end
end
