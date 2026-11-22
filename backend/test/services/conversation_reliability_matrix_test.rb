require "test_helper"

# A development regression matrix, not a held-out dataset or live-model score.
class ConversationReliabilityMatrixTest < ActiveSupport::TestCase
  SECTORS = {
    "electronics" => [ "Hoco EQ34 Plus", "Anker Nano Charger", "Hoco E103 Tracker" ],
    "clothing" => [ "Cotton Shirt", "Canvas Bag", "Summer Cap" ],
    "perfume" => [ "The Oud", "The Club", "The Office" ],
    "food" => [ "Snack Box", "Tea Pack", "Coffee Pack" ]
  }.freeze
  SIDE_QUESTIONS = [
    "How much is delivery?", "delivery charge koto?", "Dalivery chage koto",
    "ডেলিভারি চার্জ কত", "shipping fee koto?"
  ].freeze
  JOURNEYS = %w[select_and_correct append_without_reset stock_repair compare_then_shop missing_quantity_repair].freeze

  SECTORS.each do |sector, names|
    JOURNEYS.each do |journey|
      SIDE_QUESTIONS.each_with_index do |question, index|
        define_method("test_#{sector}_#{journey}_language_variant_#{index + 1}") do
          @business = Business.create!(name: "Matrix Shop", slug: "matrix-shop", category: sector)
          @products = names.map { |name| @business.products.create!(name: name, category: sector, price: 500, stock_quantity: 10) }
          @customer = SecureRandom.uuid
          first, second, third = names
          case journey
          when "select_and_correct"
            record("#{first} 2 pieces and #{second} 1 piece den")
            record("change #{first} to 1 piece")
            expected = { @products[0].id => 1, @products[1].id => 1 }
          when "append_without_reset"
            record("#{third} 1 piece den")
            record("#{first} 2 pieces and #{second} 1 piece den")
            expected = { @products[0].id => 2, @products[1].id => 1, @products[2].id => 1 }
          when "stock_repair"
            order = record("#{third} 1 piece den").pending_order
            rejected = record("add #{first} 99 pieces and #{second} 1 piece")
            assert_equal :cart_inventory_unavailable, rejected.outcome
            assert_equal({ @products[2].id => 1 }, quantities(order))
            record("add #{first} 2 pieces and #{second} 1 piece")
            expected = { @products[0].id => 2, @products[1].id => 1, @products[2].id => 1 }
          when "compare_then_shop"
            comparison = record("compare #{first} and #{second}")
            assert_empty comparison.pending_order.line_items
            record("#{first} 2 pieces and #{second} 1 piece den")
            expected = { @products[0].id => 2, @products[1].id => 1 }
          when "missing_quantity_repair"
            incomplete = record("add #{first} and #{second}")
            assert_equal :cart_needs_details, incomplete.outcome
            assert_empty incomplete.pending_order.line_items
            record("#{first} 2 pieces and #{second} 1 piece den")
            expected = { @products[0].id => 2, @products[1].id => 1 }
          end
          answer = record(question)
          order = answer.pending_order
          assert_equal :delivery_charge_requested, answer.outcome
          assert_equal expected, quantities(order)
          assert_no_match(/USB|Type-C|charging specifications/, answer.bot_reply.content)
          assert_empty @business.orders
          record("Nadia Rahman")
          record("01700000000")
          summary = record("Test address, Dhaka")
          assert_predicate summary.pending_order, :awaiting_confirmation?
          assert_equal expected, quantities(order)
          expected_total = expected.values.sum * 500
          assert_equal expected_total.to_d, order.total_price
          confirmed = record("confirm")
          assert_equal :confirmed, confirmed.outcome
          assert_equal 1, @business.orders.count
          captured = order.reload.order
          assert_equal expected, captured.order_items.pluck(:product_id, :quantity).to_h
          assert_equal expected_total.to_d, captured.total
          record("confirm")
          assert_equal 1, @business.orders.count
          assert_equal expected, order.reload.order.order_items.pluck(:product_id, :quantity).to_h
        end
      end
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
