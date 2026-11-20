require "test_helper"

class ClassificationLanguageSafetyTest < ActiveSupport::TestCase
  setup do
    @business = Business.create!(name: "Tech", slug: "classifier-language", category: "electronics")
    @business.products.create!(name: "Anker Charger", category: "charger", price: 1849, stock_quantity: 10,
      description: "Charging Cable: Confirm whether included in your package.")
    @customer = "classification-language"
  end

  test "ordinary cable and keychain questions are never explicit human requests" do
    record("need charger")
    [ "Ei charger er sathe Type C cable thakbe?", "Ei design er sathe keychain ache?" ].each do |text|
      result = record(text)
      refute_equal "human_agent", result.interpretation&.intent
      refute_predicate result.conversation.reload, :handed_over?
    end
  end

  test "equivalent explicit English and Banglish requests hand over and then stay silent" do
    [ "I need a real person to help, please.", "Bhai real seller er sathe kotha bolte chai." ].each_with_index do |text, index|
      @customer = "human-language-#{index}"
      result = record(text)
      assert_predicate result.conversation, :handed_over?
      assert_nil record("Thanks, I will wait for the seller.").bot_reply
    end
  end

  test "explicit language choice persists despite a different classifier language" do
    record("Please continue in Banglish.")
    reply = record("What is the Anker Charger price?")
    assert_includes reply.bot_reply.content, "protita"
    record("Ekhon English e bolen.")
    reply = record("Anker Charger er dam koto?")
    assert_includes reply.bot_reply.content, "each"
    refute_includes reply.bot_reply.content, "protita"
  end

  test "electronics price replies never use perfume units" do
    result = record("What is the Anker Charger price?")
    refute_includes result.bot_reply.content, "bottle"
  end

  test "asking whether the assistant is human is identity not takeover" do
    result = record("Are you human?")
    assert_equal "bot_identity", result.interpretation.intent
    refute_predicate result.conversation.reload, :handed_over?
  end

  test "Banglish factual follow ups retain the single offered product" do
    @business.products.first.update!(description: "Charging Cable: Confirm whether included in your package. Actual speed depends on the device and protocol.")
    record("Charger lagbe")
    result = record("Ei charger er sathe Type C cable thakbe?")
    assert_includes result.bot_reply.content, "verified nei"
    assert_nil result.pending_order.reload.product_id
    result = record("Warranty koto din?")
    assert_includes result.bot_reply.content, "Warranty"
    refute_predicate result.conversation, :handed_over?
    result = record("Amar phone ki sob somoy 45 watt e charge hobe?")
    assert_includes result.bot_reply.content, "depends on the device"
  end

  test "name introductions are checkout data rather than factual questions" do
    record("I want to buy Anker Charger")
    record("2 pieces")
    result = record("My name is SQA Customer I")
    assert_equal "SQA Customer I", result.pending_order.reload.customer_name
  end

  private

  def record(text)
    CustomerMessageRecorder.new(business: @business, channel: "facebook", external_customer_id: @customer, content: text).record
  end
end
