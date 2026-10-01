require "test_helper"

class ConversationToolGatewayTest < ActiveSupport::TestCase
  setup do
    @business = Business.create!(name: "Tool Shop", slug: "tool-shop")
    @other_business = Business.create!(name: "Other Shop", slug: "other-shop")
    @product = @business.products.create!(
      name: "The Oud", price: 0, stock_quantity: 0, description: "Warm woody oud",
      product_attributes: { "scent_family" => "oud" }
    )
    @variant = @product.product_variants.create!(name: "30 ML", size: "30 ML", price: 850, stock_quantity: 4)
    @other_business.products.create!(name: "Private Product", price: 100, stock_quantity: 10)
    @business.create_business_policy!(delivery_charges: "Dhaka ৳80")
    @conversation = @business.conversations.create!(channel: "facebook", external_customer_id: SecureRandom.uuid)
    @order = @conversation.create_pending_order!(
      product: @product, product_variant: @variant, quantity: 2, customer_name: "Anik",
      phone: "01712345678", address: "Dhaka", status: :awaiting_confirmation
    )
    @gateway = ConversationToolGateway.new(conversation: @conversation, pending_order: @order)
  end

  test "searches only the current business active catalogue" do
    response = @gateway.call("search_products", query: "oud under 1000", limit: 3)
    names = response.dig("result", "matches").pluck("product_name")

    assert_equal [ "The Oud" ], names
    assert_not_includes names, "Private Product"
  end

  test "returns grounded product and variant data" do
    details = @gateway.call("get_product_details", product_id: @product.id).fetch("result")
    variants = @gateway.call("get_variant_availability", product_id: @product.id).fetch("result")

    assert_equal "The Oud", details.fetch("name")
    assert_equal "850.0", details.fetch("starting_price")
    assert_equal "30 ML", variants.fetch("variants").first.fetch("name")
    assert_equal 4, variants.fetch("variants").first.fetch("stock_quantity")
  end

  test "does not expose another business product by id" do
    private_product = @other_business.products.find_by!(name: "Private Product")

    assert_equal({ "found" => false }, @gateway.call("get_product_details", product_id: private_product.id).fetch("result"))
  end

  test "returns only an approved policy field" do
    response = @gateway.call("get_business_policy", topic: "delivery_charges").fetch("result")

    assert_equal "Dhaka ৳80", response.fetch("value")
    assert_raises(ArgumentError) { @gateway.call("get_business_policy", topic: "encrypted_credentials") }
  end

  test "order summary hides customer contact values" do
    summary = @gateway.call("get_order_summary").fetch("result")

    assert summary.fetch("has_phone")
    assert summary.fetch("has_address")
    assert_not_includes summary.values, "01712345678"
    assert_not_includes summary.values, "Dhaka"
  end

  test "rejects tools outside the allowlist" do
    assert_raises(ConversationToolGateway::UnsupportedTool) do
      @gateway.call("run_sql", sql: "select * from users")
    end
  end
end
