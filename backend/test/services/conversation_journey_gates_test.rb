require "test_helper"
require_relative "../support/conversation_journey_assertions"

class ConversationJourneyGatesTest < ActiveSupport::TestCase
  include ConversationJourneyAssertions

  setup do
    @business = Business.create!(name: "Journey Devices", slug: "journey-devices", category: "electronics")
    @charger = @business.products.create!(name: "Anker Nano 45W", category: "charger", price: 1849, stock_quantity: 10)
    @buds = @business.products.create!(name: "Hoco EQ34 Plus", category: "earbuds", price: 729, stock_quantity: 10)
  end

  test "independent purchase phrasings progress from offer to quantity with no AI" do
    [ "etai nibo", "ai product tai nite chai", "charger ta", "I will take this one" ].each do |phrase|
      assert_conversation_journey(business: @business, steps: [
        { say: "charger ase?", includes: [ "1849" ], order: { product_id: nil, quantity: nil } },
        { say: phrase, order: { product_id: @charger.id, quantity: nil, status: "collecting_quantity" } },
        { say: "2 pieces", order: { product_id: @charger.id, quantity: 2, status: "collecting_name" } },
        { say: "Cancel this test order.", order: { status: "cancelled" } }
      ])
    end
  end

  test "questions and postponement never silently create a purchase" do
    assert_conversation_journey(business: @business, steps: [
      { say: "charger ase?", order: { product_id: nil } },
      { say: "Ei charger er sathe cable thakbe?", includes: [ "verified" ], order: { product_id: nil } },
      { say: "What is the total for two Anker Nano 45W before delivery?", includes: [ "3698" ], order: { product_id: nil, quantity: nil } },
      { say: "I am just browsing, do not place an order.", order: { product_id: nil, quantity: nil } }
    ])
  end

  test "side questions preserve checkout and corrections alter only their target" do
    assert_conversation_journey(business: @business, steps: [
      { say: "Hoco EQ34 Plus nibo", order: { product_id: @buds.id, quantity: nil } },
      { say: "2 pieces", order: { product_id: @buds.id, quantity: 2, status: "collecting_name" } },
      { say: "delivery charge koto?", order: { product_id: @buds.id, quantity: 2, status: "collecting_name" } },
      { say: "Actually change the quantity to 3.", order: { product_id: @buds.id, quantity: 3 } },
      { say: "cancel", order: { status: "cancelled" } }
    ])
  end

  test "negative English and Banglish purchase replies do not select an offered product" do
    [ "etai nibo na", "I do not want to buy this", "ei charger nite chai na" ].each do |phrase|
      assert_conversation_journey(business: @business, steps: [
        { say: "charger ase?", order: { product_id: nil } },
        { say: phrase, order: { product_id: nil, quantity: nil } }
      ])
    end
  end

  test "purchase with multiple catalogue questions answers them and retains checkout" do
    @buds.update!(description: "Battery playback up to 7 hours. ANC is supported.")
    assert_conversation_journey(business: @business, steps: [
      { say: "Hoco EQ34 Plus nibo. Battery koto khon chole? ANC ache?", includes: [ "7 hours", "ANC" ],
        order: { product_id: @buds.id, quantity: nil } },
      { say: "2 pieces", order: { product_id: @buds.id, quantity: 2 } }
    ])
  end

  test "conjoined English and Banglish FAQs are not additional cart items" do
    @buds.update!(description: "Battery playback up to 7 hours. ANC is supported.")
    [
      "I will take Hoco EQ34 Plus. How long does the battery last, and does it have ANC?",
      "Hoco EQ34 Plus nibo. Battery koto khon chole ar ANC ache?"
    ].each do |phrase|
      results = assert_conversation_journey(business: @business, steps: [
        { say: "earbuds under 800 taka", order: { product_id: nil } },
        { say: phrase, includes: [ "7 hours", "ANC" ], excludes: [ "unknown item" ],
          order: { product_id: @buds.id, quantity: nil, status: "collecting_quantity" } },
        { say: "Two pieces.", order: { product_id: @buds.id, quantity: 2, status: "collecting_name" } },
        { say: "cancel", order: { status: "cancelled" } }
      ])
      assert_nil results[1].conversation.reload.conversation_state["cart_repair"]
    end
  end

  test "explicit quantity and conjoined facts keep a single product order" do
    @buds.update!(description: "Battery playback up to 7 hours. ANC is supported.")
    assert_conversation_journey(business: @business, steps: [
      { say: "Hoco EQ34 Plus 2 pieces nibo and does it have ANC?", includes: [ "ANC" ],
        order: { product_id: @buds.id, quantity: 2, status: "collecting_name" } }
    ])
  end

  test "unknown purchases remain unresolved even when followed by a FAQ" do
    results = assert_conversation_journey(business: @business, steps: [
      { say: "I will take Hoco EQ34 Plus and Moon Mist 2 pieces. Does it have ANC?",
        includes: [ "unknown item" ], order: { product_id: nil, quantity: nil } }
    ])
    assert results.last.conversation.reload.conversation_state.dig("cart_repair", "unknown")
  end

  test "genuine two product carts still retain both quantities alongside questions" do
    results = assert_conversation_journey(business: @business, steps: [
      { say: "Anker Nano 45W 1 piece and Hoco EQ34 Plus 2 pieces nibo and does it have ANC?" }
    ])
    items = results.last.pending_order.reload.line_items.to_h { |item| [ item.product_id, item.quantity ] }
    assert_equal({ @charger.id => 1, @buds.id => 2 }, items)
    assert_nil results.last.conversation.reload.conversation_state["cart_repair"]
  end
end
