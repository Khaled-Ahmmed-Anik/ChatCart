require "test_helper"

class ConversationExperienceTest < ActiveSupport::TestCase
  setup do
    @business = Business.create!(name: "Experience Shop", slug: "experience-reliability", category: "electronics")
    @product = @business.products.create!(name: "Hoco EQ34 Plus", price: 729, stock_quantity: 20)
    @conversation = @business.conversations.create!(channel: "facebook", external_customer_id: SecureRandom.uuid)
    @order = @conversation.pending_orders.create!(status: :collecting_product)
  end

  test "welcome uses all supported languages without a catalogue dump or guessed title" do
    { "english" => "What are you looking for?", "banglish" => "Ki khujchen?", "bengali" => "কী খুঁজছেন?" }.each do |language, expected|
      @conversation.update!(conversation_state: { "preferred_language" => language, "language_explicit" => true })
      reply = reply_for(:greeting, "hi")
      assert_includes reply, @business.name
      assert_includes reply, expected
      assert_not_includes reply, @product.name
      assert_no_match(/\b(?:bhai|sir|madam)\b/, reply)
      assert_nil @conversation.reload.conversation_state["last_offered_options"]
    end
  end

  test "greeting during checkout keeps the selected item and pending field" do
    @order.update!(product: @product, quantity: 2, status: :collecting_name)
    assert_match(/name/i, reply_for(:greeting, "hi"))
    assert_equal 2, @order.reload.quantity
    assert_equal @product.id, @order.product_id
  end

  test "missing delivery policy uses a localized honest answer" do
    @conversation.update!(conversation_state: { "preferred_language" => "banglish", "language_explicit" => true })
    reply = reply_for(:delivery_charge_requested, "delivery charge koto")
    assert_includes reply, "Seller-er confirmation lagbe"
    assert_no_match(/৳|notified|passed|janao hoyeche/, reply)
  end

  test "bounded confirmation typo confirms once and keeps the remembered language" do
    @order.update!(product: @product, quantity: 1, customer_name: "Test Buyer", phone: "01700000000",
      address: "Test address", status: :awaiting_confirmation)
    @conversation.update!(conversation_state: { "preferred_language" => "banglish", "language_explicit" => true })
    result = CustomerMessageRecorder.new(business: @business, channel: "facebook",
      external_customer_id: @conversation.external_customer_id, content: "confrim").record
    assert_equal :confirmed, result.outcome
    assert_includes result.bot_reply.content, "Apnar order confirm hoyeche"
    assert_equal 1, @business.orders.count
  end

  private

  def reply_for(outcome, content)
    message = @conversation.messages.create!(sender_type: :customer, content: content)
    BotReplyGenerator.new(pending_order: @order, customer_message: message, outcome: outcome).content
  end
end
