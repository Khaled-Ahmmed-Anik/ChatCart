require "test_helper"

class OrderCaptureServiceTest < ActiveSupport::TestCase
  test "snapshots the selected variant and its exact price" do
    business = Business.create!(name: "Variant Shop", slug: "variant-shop")
    product = business.products.create!(name: "The Oud", price: 250, stock_quantity: 0)
    variant = product.product_variants.create!(name: "6 ml", size: "6 ml", price: 450, stock_quantity: 5)
    conversation = business.conversations.create!(channel: "facebook", external_customer_id: SecureRandom.uuid)
    pending_order = conversation.create_pending_order!(
      product: product, product_variant: variant, quantity: 2, customer_name: "Buyer",
      phone: "01712345678", address: "Dhaka", status: :confirmed
    )

    order = OrderCaptureService.new(pending_order).capture
    item = order.order_items.sole

    assert_equal 900.to_d, order.total
    assert_equal variant, item.product_variant
    assert_equal "6 ml", item.variant_name
    assert_equal 450.to_d, item.unit_price
    assert_equal 900.to_d, item.total
  end
end
