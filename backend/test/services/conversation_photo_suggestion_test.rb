require "test_helper"
require_relative "../support/photo_test_stubs"

class ConversationPhotoSuggestionTest < ActiveJob::TestCase
  include PhotoTestStubs

  setup do
    @business = Business.create!(name: "Photo Followups", slug: "photo-followups", default_language: "english")
    @product = @business.products.create!(name: "The Oud", price: 500, stock_quantity: 10)
    @variant = @product.product_variants.create!(name: "15 ML", size: "15 ML", price: 500, stock_quantity: 10)
    @conversation = @business.conversations.create!(channel: "facebook", external_customer_id: "followup-customer")
    @event = MessengerWebhookEvent.create!(business: @business, sender_id: @conversation.external_customer_id,
      event_type: "customer_image", status: "received", external_event_id: "followup-photo",
      payload: { message: { attachments: [ { type: "image", payload: { url: "https://images.example.com/photo.jpg" } } ] } })
    recognizer = Object.new
    product = @product
    recognizer.define_singleton_method(:recognize) { product }
    with_photo_stub(CustomerPhotoRecognizer, :new, recognizer) { ProcessMessengerImageJob.perform_now(@event) }
    @conversation.reload
  end

  test "yes this one selects the pictured product then size and quantity use existing flow" do
    result = nil
    with_photo_stub(AiIntentClassifier, :new, ->(**) { flunk "Photo confirmation must not call an LLM" }) do
      with_photo_stub(AiConversationAssistant, :new, ->(**) { flunk "Photo confirmation must remain deterministic" }) do
        result = say("yes, this one")
      end
    end
    assert_equal @product, result.pending_order.product
    assert_predicate result.pending_order, :collecting_variant?
    assert_includes result.bot_reply.content, "15 ML"
    assert_nil result.pending_order.quantity, "The word 'one' refers to a product, not one bottle"
    assert_equal "yes, this one", result.message.content
    assert_equal "photo_confirmation", result.message.metadata["intent_classifier"]
    assert_not @conversation.reload.conversation_state.key?("photo_suggestion")
    assert_equal 0, @conversation.orders.count
    result = say("15 ML")
    assert_equal @variant, result.pending_order.product_variant
    assert_predicate result.pending_order, :collecting_quantity?
    result = say("2")
    assert_equal 2, result.pending_order.quantity
    assert_predicate result.pending_order, :collecting_name?
  end

  test "Bangla and Banglish confirmations identify the same scoped product" do
    [ "জি", "হ্যাঁ", "eita nibo", "ji", "this one", "yes please" ].each do |text|
      offer_again
      message = @conversation.messages.create!(sender_type: :customer, content: text)
      result = ConversationPhotoSuggestion.new(@conversation).resolve(message: message, pending_order: nil)
      assert_equal @product, result.product, text
    end
  end

  test "this one is not a quantity for a product without size variants" do
    @variant.destroy!
    result = say("this one")
    assert_equal @product, result.pending_order.product
    assert_predicate result.pending_order, :collecting_quantity?
    assert_nil result.pending_order.quantity
    assert_equal 0, @conversation.orders.count
  end

  test "acknowledging a photo cannot confirm or overwrite an existing checkout" do
    cart = @conversation.create_pending_order!(product: @product, product_variant: @variant, quantity: 2,
      customer_name: "Test Buyer", phone: "01712345678", address: "Badda", status: :awaiting_confirmation)
    original = cart.attributes
    assert_no_difference -> { Order.count } do
      result = say("yes")
      assert_includes result.bot_reply.content, "order in progress"
    end
    assert_equal original, cart.reload.attributes
    assert_no_difference -> { Order.count } do
      say("yes")
    end
    assert_predicate cart.reload, :awaiting_confirmation?
    assert_difference -> { Order.count }, 1 do
      say("confirm")
    end
    assert_predicate cart.reload, :confirmed?
  end

  test "photo approval cannot silently start a new cart after an already confirmed order" do
    cart = @conversation.create_pending_order!(product: @product, product_variant: @variant, quantity: 2,
      customer_name: "Test Buyer", phone: "01712345678", address: "Badda", status: :confirmed)
    original = cart.attributes
    assert_no_difference [ -> { PendingOrder.count }, -> { Order.count } ] do
      result = say("yes, this one")
      assert_includes result.bot_reply.content, "new order"
    end
    assert_equal original, cart.reload.attributes
  end

  test "negative answer and expired offer never create an order" do
    assert_no_difference -> { PendingOrder.count } do
      result = say("no, not this one")
      assert_includes result.bot_reply.content, "another photo"
    end
    offer_again
    travel Constants::PhotoRecognition::SUGGESTION_LIFETIME + 1.second do
      assert_no_difference -> { PendingOrder.count } do
        result = say("yes")
        assert_includes result.bot_reply.content, "new photo"
      end
    end
  end

  test "side questions invalidate the photo proposal without hijacking normal replies" do
    say("delivery charge?")
    assert_not @conversation.reload.conversation_state.key?("photo_suggestion")
    result = say("yes")
    assert_nil result.pending_order.product
    assert_equal 0, @conversation.orders.count
  end

  test "deactivated archived and out of stock matches cannot be selected" do
    [ { active: false }, { active: true, archived_at: Time.current }, { active: true, archived_at: nil } ].each_with_index do |attributes, index|
      offer_again
      @product.update!(attributes)
      @variant.update!(stock_quantity: 0) if index == 2
      result = say("yes")
      assert_includes result.bot_reply.content, "isn't available"
      assert_nil @conversation.pending_order
    end
  end

  test "a newer photo receipt invalidates a previous unconsumed proposal" do
    MessengerWebhookEvent.create!(business: @business, sender_id: @conversation.external_customer_id,
      event_type: "customer_image", status: "received", external_event_id: "newer-photo", payload: {}, created_at: @event.created_at + 1.second)
    result = say("yes")
    assert_includes result.bot_reply.content, "new photo"
    assert_nil result.pending_order
  end

  test "a foreign tenant product cannot be selected from tampered suggestion data" do
    other = Business.create!(name: "Other Photo Shop", slug: "other-photo-followups")
    foreign = other.products.create!(name: "Private Product", price: 100, stock_quantity: 10)
    state = @conversation.conversation_state.deep_dup
    state["photo_suggestion"]["product_id"] = foreign.id
    @conversation.update!(conversation_state: state)
    reply = @conversation.messages.bot.last
    reply.update!(metadata: reply.metadata.merge("suggested_product_id" => foreign.id))
    result = say("yes")
    assert_nil result.pending_order
    refute_includes result.bot_reply.content, "Private Product"
  end

  test "human takeover prevents automated photo confirmation" do
    @conversation.handed_over!
    assert_no_difference -> { PendingOrder.count } do
      result = say("yes")
      assert_nil result.bot_reply
      assert_equal :awaiting_human, result.outcome
    end
  end

  test "vague acknowledgement is not an explicit photo product selection" do
    message = @conversation.messages.create!(sender_type: :customer, content: "hmm")
    assert_nil ConversationPhotoSuggestion.new(@conversation).resolve(message: message, pending_order: nil)
    assert_nil @conversation.pending_order
    assert_not @conversation.reload.conversation_state.key?("photo_suggestion")
  end

  test "photo replies from before deployment without suggestion state ask for clarification" do
    @conversation.update!(conversation_state: @conversation.conversation_state.except("photo_suggestion"))
    assert_no_difference -> { PendingOrder.count } do
      result = say("yes")
      assert_includes result.bot_reply.content, "new photo"
    end
  end

  test "slow Messenger profile lookup cannot overwrite a newly offered photo suggestion" do
    @conversation.update!(conversation_state: {})
    earlier_text = MessengerWebhookEvent.create!(business: @business, sender_id: @conversation.external_customer_id,
      event_type: "customer_text", status: "received", external_event_id: "profile-text",
      created_at: @event.created_at - 1.second, payload: { message: { text: "delivery charge?" } })
    new_photo = MessengerWebhookEvent.create!(business: @business, sender_id: @conversation.external_customer_id,
      event_type: "customer_image", status: "received", external_event_id: "during-profile-photo", payload: @event.payload)
    recognizer = Object.new
    product = @product
    recognizer.define_singleton_method(:recognize) { product }
    profile = Object.new
    profile.define_singleton_method(:name) do
      ProcessMessengerImageJob.perform_now(new_photo)
      "Test Buyer"
    end
    with_photo_stub(CustomerPhotoRecognizer, :new, recognizer) do
      with_photo_stub(MessengerCustomerProfile, :new, profile) do
        ProcessMessengerEventJob.perform_now(earlier_text)
      end
    end
    state = @conversation.reload.conversation_state
    assert_equal @product.id, state.dig("photo_suggestion", "product_id")
    assert_equal "Test Buyer", state.dig("customer_profile", "name")
  end

  private

  def say(text)
    CustomerMessageRecorder.new(business: @business, channel: "facebook", external_customer_id: @conversation.external_customer_id, content: text).record
  end

  def offer_again
    @conversation.reload
    reply = @conversation.messages.create!(sender_type: :bot, content: "Photo match", metadata: { "photo_recognition" => true, "suggested_product_id" => @product.id })
    ConversationPhotoSuggestion.new(@conversation).offer!(product: @product, reply: reply, event: @event)
  end
end
