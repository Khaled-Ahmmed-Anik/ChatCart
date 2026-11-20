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
end
