require "test_helper"

class CustomerMessageRecorderTest < ActiveSupport::TestCase
  test "records customer message, processes pending order, and creates bot reply" do
    product = Product.create!(name: "Fresh Musk", price: 750, stock_quantity: 10)

    result = CustomerMessageRecorder.new(
      channel: "facebook",
      external_customer_id: "fb-user-123",
      content: "I want Fresh Musk",
      metadata: { "source" => "messenger" }
    ).record

    assert_equal "facebook", result.conversation.channel
    assert_equal "fb-user-123", result.conversation.external_customer_id
    assert_equal "I want Fresh Musk", result.message.content
    assert_equal({ "source" => "messenger" }, result.message.metadata)
    assert_equal product, result.pending_order.product
    assert_predicate result.pending_order, :collecting_quantity?
    assert_equal "Great choice. How many bottles of Fresh Musk would you like?", result.bot_reply.content
  end
end
