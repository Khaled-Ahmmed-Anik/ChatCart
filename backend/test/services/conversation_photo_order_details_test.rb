require "test_helper"
require_relative "../support/photo_test_stubs"

class ConversationPhotoOrderDetailsTest < ActiveJob::TestCase
  include PhotoTestStubs

  setup do
    @business = Business.create!(name: "Caption Shop", slug: "caption-shop", default_language: "english")
    @product = @business.products.create!(name: "The Oud", price: 400, stock_quantity: 20)
    @small = @product.product_variants.create!(name: "15 ML", size: "15 ML", price: 400, stock_quantity: 20)
    @large = @product.product_variants.create!(name: "30 ML", size: "30 ML", price: 700, stock_quantity: 5)
    @conversation = @business.conversations.create!(channel: "facebook", external_customer_id: "caption-buyer")
  end

  test "English Banglish and Bangla captions retain size and quantity until product approval" do
    [ "I want this one 30 ML two bottles", "eitar 30 ml duita chai", "এইটার ৩০ মিলি দুইটা চাই", "এইটার 30 ML ২টা চাই" ].each_with_index do |caption, index|
      @conversation.pending_order&.destroy!
      offer(caption, index: index)
      assert_nil @conversation.reload.pending_order
      result = approve
      assert_equal @product, result.pending_order.product, caption
      assert_equal @large, result.pending_order.product_variant, caption
      assert_equal 2, result.pending_order.quantity, caption
      assert_predicate result.pending_order, :collecting_name?
      assert_equal "yes, this one", result.message.content
      assert_equal 0, @conversation.orders.count
    end
  end

  test "caption details are shown as pending not as an already placed order" do
    reply = offer("I want this one 30 ML 2 bottles")
    assert_includes reply.content, "30 ML"
    assert_includes reply.content, "2 pieces"
    assert_includes reply.content, "After you confirm"
    assert_includes reply.content, "does not place"
    assert_nil @conversation.reload.pending_order
  end

  test "size only does not treat this one or volume as bottle quantity" do
    offer("I want this one 30 ML")
    result = approve
    assert_equal @large, result.pending_order.product_variant
    assert_nil result.pending_order.quantity
    assert_predicate result.pending_order, :collecting_quantity?
  end

  test "unavailable size asks for an option instead of guessing a smaller size" do
    offer("I want this one 100 ML two bottles")
    result = approve
    assert_nil result.pending_order.product_variant
    assert_predicate result.pending_order, :collecting_variant?
    assert_includes result.bot_reply.content, "30 ML"
    assert_equal 2, result.pending_order.quantity
  end

  test "quantity without size is retained and checked when the customer chooses a size" do
    offer("I want two bottles")
    result = approve
    assert_equal 2, result.pending_order.quantity
    assert_predicate result.pending_order, :collecting_variant?
    result = say("30 ML")
    assert_equal 2, result.pending_order.quantity
    assert_predicate result.pending_order, :collecting_name?
  end

  test "retained quantity is not accepted when the chosen variant has insufficient stock" do
    offer("I want ten bottles")
    approve
    result = say("30 ML")
    assert_equal :quantity_unavailable, result.outcome
    assert_nil result.pending_order.quantity
    assert_predicate result.pending_order, :collecting_quantity?
  end

  test "negative fractional and multiple quantities ask for clarification without cart mutation" do
    [ "want -2 bottles 30 ML", "want 2.5 bottles 30 ML", "want 2 bottles and 3 bottles 30 ML", "want two bottles and three bottles" ].each_with_index do |caption, index|
      offer(caption, index: index)
      assert_no_difference -> { PendingOrder.count } do
        result = approve
        assert_includes result.bot_reply.content, "whole-number"
      end
    end
  end

  test "stock is checked again at approval and current price is used" do
    offer("I want this one 30 ML two bottles")
    @large.update!(price: 750, stock_quantity: 1)
    result = approve
    assert_nil result.pending_order.quantity
    assert_equal :quantity_unavailable, result.outcome
    assert_equal 750, result.pending_order.unit_price
    assert_equal 0, @conversation.orders.count
  end

  test "questions deferrals negations and alternative options do not execute caption quantities" do
    [ "Is this available in 30 ML two bottles?", "I want 30 ML two bottles later", "30 ml duita nibo na", "৩০ মিলি দুইটা চাই না", "want 15 ML or 30 ML two bottles" ].each_with_index do |caption, index|
      @conversation.pending_order&.destroy!
      offer(caption, index: index)
      result = approve
      assert_nil result.pending_order.quantity, caption
      assert_nil result.pending_order.product_variant, caption
    end
  end

  test "explicit add caption preserves the existing cart and adds the photo product" do
    other = @business.products.create!(name: "The Office", price: 300, stock_quantity: 10)
    cart = @conversation.create_pending_order!(product: other, quantity: 1, status: :collecting_name)
    offer("add this one 30 ML two bottles")
    result = approve
    assert_equal :cart_updated, result.outcome
    assert_equal [ other.id, @product.id ].sort, cart.reload.line_items.map(&:product_id).sort
    assert_equal 2, cart.line_items.find { |item| item.product_id == @product.id }.quantity
    assert_equal 1700, cart.total_price
    assert_equal 0, @conversation.orders.count
  end

  test "photo approval updates a complete draft but only a separate confirmation captures the order" do
    other = @business.products.create!(name: "The Office", price: 300, stock_quantity: 10)
    @conversation.create_pending_order!(product: other, quantity: 1, customer_name: "Test Buyer",
      phone: "01712345678", address: "Badda", status: :awaiting_confirmation)
    offer("add this one 30 ML two bottles")
    assert_no_difference -> { Order.count } do
      result = approve
      assert_predicate result.pending_order, :awaiting_confirmation?
      assert_equal 1700, result.pending_order.total_price
    end
    assert_difference -> { Order.count }, 1 do
      say("confirm my order")
    end
    assert_equal 2, @conversation.orders.last.order_items.count
  end

  test "add caption cannot overwrite an unfinished current item" do
    other = @business.products.create!(name: "Blue Shirt", price: 300, stock_quantity: 10)
    cart = @conversation.create_pending_order!(product: other, status: :collecting_quantity)
    original = cart.attributes
    offer("add this one 30 ML two bottles")
    result = approve
    assert_equal :cart_needs_details, result.outcome
    assert_equal original, cart.reload.attributes
  end

  test "photo addition checks aggregate stock for the same item" do
    cart = @conversation.create_pending_order!(product: @product, product_variant: @large, quantity: 4, status: :collecting_name)
    original = cart.attributes
    offer("add this one 30 ML two bottles")
    result = approve
    assert_equal :cart_inventory_unavailable, result.outcome
    assert_equal original, cart.reload.attributes
    assert_equal 4, cart.line_items.first.quantity
  end

  test "photo addition with missing size retains quantity for the next turn" do
    other = @business.products.create!(name: "The Office", price: 300, stock_quantity: 10)
    cart = @conversation.create_pending_order!(product: other, quantity: 1, status: :collecting_name)
    offer("add this one two bottles")
    approve
    result = say("30 ML")
    assert_equal 2, result.pending_order.quantity
    assert_equal [ other.id, @product.id ].sort, cart.reload.line_items.map(&:product_id).sort
  end

  test "missing-size photo addition checks stock together with saved cart lines" do
    cart = @conversation.create_pending_order!(product: @product, product_variant: @large, quantity: 4, status: :collecting_name)
    offer("add this one two bottles")
    approve
    result = say("30 ML")
    assert_equal :quantity_unavailable, result.outcome
    assert_nil result.pending_order.quantity
    assert_equal 4, cart.reload.pending_order_items.sum(:quantity)
    assert_equal 0, @conversation.orders.count
  end

  test "standard option accepts quantity without repeating its sole option" do
    @product.product_variants.destroy_all
    standard = @product.product_variants.create!(name: "Standard", price: 400, stock_quantity: 10)
    offer("want two pieces")
    result = approve
    assert_equal standard, result.pending_order.product_variant
    assert_equal 2, result.pending_order.quantity
    assert_predicate result.pending_order, :collecting_name?
  end

  test "caption preview uses the conversation locale and pluralization" do
    @conversation.update!(conversation_state: { preferred_language: "banglish" })
    reply = offer("eitar 30 ML duita chai")
    assert_includes reply.content, "2 ta"
    assert_includes reply.content, "note korechi"
    assert_not_includes reply.content, "2 pieces"
  end

  test "without explicit add an existing checkout stays unchanged" do
    cart = @conversation.create_pending_order!(product: @product, product_variant: @small, quantity: 1, status: :awaiting_confirmation)
    original = cart.attributes
    offer("I want this one 30 ML two bottles")
    result = approve
    assert_includes result.bot_reply.content, "order in progress"
    assert_equal original, cart.reload.attributes
  end

  test "add caption cannot reopen a confirmed order" do
    cart = @conversation.create_pending_order!(product: @product, product_variant: @small, quantity: 1, status: :confirmed)
    original = cart.attributes
    offer("add this one 30 ML two bottles")
    result = approve
    assert_includes result.bot_reply.content, "new order"
    assert_equal original, cart.reload.attributes
  end

  test "a conflicting caption product asks for clarification without starting an order" do
    @business.products.create!(name: "The Office", price: 300, stock_quantity: 10)
    offer("I want The Office 30 ML two bottles")
    result = approve
    assert_nil result.pending_order
    assert_includes result.bot_reply.content, "different items"
    assert_equal 0, @conversation.orders.count
  end

  test "rejection and expiry cannot execute retained caption instructions" do
    offer("I want this one 30 ML two bottles")
    assert_no_difference -> { PendingOrder.count } do
      say("no")
    end
    offer("I want this one 30 ML two bottles", index: 1)
    travel Constants::PhotoRecognition::SUGGESTION_LIFETIME + 1.second do
      assert_no_difference -> { PendingOrder.count } do
        approve
      end
    end
  end

  test "photo details are scoped to the suggested product across different business sectors" do
    shirt = @business.products.create!(name: "Blue Shirt", price: 600, stock_quantity: 10,
      product_attributes: { option_aliases: { "Large" => [ "boro" ] } })
    large = shirt.product_variants.create!(name: "Large", size: "L", price: 600, stock_quantity: 10)
    offer("want large two pieces", product: shirt)
    result = approve
    assert_equal shirt, result.pending_order.product
    assert_equal large, result.pending_order.product_variant
    assert_equal 2, result.pending_order.quantity
  end

  private

  def approve
    with_photo_stub(AiIntentClassifier, :new, ->(**) { flunk "Approval must not call AI" }) do
      with_photo_stub(AiConversationAssistant, :new, ->(**) { flunk "Approval must not call AI" }) { say("yes, this one") }
    end
  end

  def say(text)
    CustomerMessageRecorder.new(business: @business, channel: "facebook", external_customer_id: @conversation.external_customer_id, content: text).record
  end

  def offer(caption, index: 0, product: @product)
    event = MessengerWebhookEvent.create!(business: @business, sender_id: @conversation.external_customer_id,
      event_type: "customer_image", status: "received", external_event_id: "caption-photo-#{index}",
      payload: { message: { text: caption, attachments: [ { type: "image", payload: { url: "https://images.example.com/product.jpg" } } ] } })
    recognizer = Object.new
    recognizer.define_singleton_method(:recognize) { product }
    with_photo_stub(CustomerPhotoRecognizer, :new, recognizer) { ProcessMessengerImageJob.perform_now(event) }
    @conversation.reload
    event.reload.messenger_delivery.message
  end
end
