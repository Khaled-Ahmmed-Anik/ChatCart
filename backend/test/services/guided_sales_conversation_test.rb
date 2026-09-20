require "test_helper"

class GuidedSalesConversationTest < ActiveSupport::TestCase
  setup do
    @conversation = Conversation.create!(channel: "facebook", external_customer_id: SecureRandom.uuid)
    @order = @conversation.create_pending_order!
    @flow = GuidedSalesConversation.new(@conversation)
  end

  test "tracks the guided sales journey independently from wording" do
    @flow.sync!(outcome: :product_recommendation_requested, pending_order: @order)
    assert_equal "discover", @flow.stage

    product = Product.create!(name: "The Office", price: 350, stock_quantity: 10)
    @order.update!(product: product, status: :collecting_quantity)
    @flow.sync!(outcome: :product_selected, pending_order: @order)
    assert_equal "select", @flow.stage

    @flow.sync!(outcome: :no_change, pending_order: @order)
    assert_equal "configure", @flow.stage

    @order.update!(quantity: 1, status: :collecting_name)
    @flow.sync!(outcome: :quantity_collected, pending_order: @order)
    assert_equal "checkout", @flow.stage

    @order.update!(customer_name: "Anik", phone: "01712345678", address: "Dhaka", status: :awaiting_confirmation)
    @flow.sync!(outcome: :address_collected, pending_order: @order)
    assert_equal "confirm", @flow.stage

    @order.update!(status: :confirmed)
    @flow.sync!(outcome: :confirmed, pending_order: @order)
    assert_equal "complete", @flow.stage
  end

  test "reset clears both the flow and accumulated shopping preferences" do
    @conversation.update!(conversation_state: {
      "guided_sales" => { "stage" => "discover" },
      "shopping_preferences" => { "format" => "single" },
      "preferred_language" => "banglish"
    })

    @flow.reset!

    state = @conversation.reload.conversation_state
    assert_nil state["guided_sales"]
    assert_nil state["shopping_preferences"]
    assert_equal "banglish", state["preferred_language"]
  end

  test "suspends and restores an order while the customer browses" do
    product = Product.create!(name: "The Office", price: 350, stock_quantity: 10)
    @order.update!(product: product, quantity: 2, status: :collecting_name)

    @flow.suspend_order!(@order)
    @order.update!(product: nil, quantity: nil, status: :collecting_product)

    assert @flow.resume_order!(@order)
    assert_equal product, @order.reload.product
    assert_equal 2, @order.quantity
    assert_predicate @order, :collecting_name?
    assert_equal "checkout", @flow.stage
  end

  test "tracks rejected recommendations and a shortlist" do
    @flow.transition!("discover")
    @flow.remember_recommendations!([ 10, 20, 30 ])
    assert_equal [ 10, 20, 30 ], @flow.context["last_recommended_product_ids"]

    @flow.add_to_shortlist!([ 10, 20 ])
    assert_equal [ 10, 20 ], @flow.context["shortlist_product_ids"]

    @flow.remove_from_shortlist!([ 10 ])
    assert_equal [ 20 ], @flow.context["shortlist_product_ids"]

    assert_equal [ 10, 20, 30 ], @flow.reject_last_recommendations!
  end
end
