require "test_helper"

class CompactIntentClassifierTest < ActiveSupport::TestCase
  HELD_OUT_CASES = {
    "hello there" => "greeting",
    "kemon asen bhai" => "wellbeing",
    "shobgula product dekhte chai" => "list_products",
    "etar dam ta bolben" => "product_price",
    "stock e pawa jabe" => "product_availability",
    "available size gulo ki" => "product_variants",
    "ei perfume somporke bolen" => "product_details",
    "amar jonno ekta perfume choose koren" => "product_recommendation",
    "duitar moddhe konta valo" => "compare_products",
    "arekta order korte chai" => "new_order",
    "order er summary den" => "order_details",
    "হ্যাঁ অর্ডারটা কনফার্ম করেন" => "confirm_order",
    "এই অর্ডারটা বাদ দেন" => "cancel_order",
    "outside dhaka shipping koto" => "delivery_charge",
    "parcel ashte koy din lagbe" => "delivery_time",
    "amar location e pathaben" => "delivery_area",
    "card diye pay kora jabe" => "payment_methods",
    "product pawar por taka dibo" => "cash_on_delivery",
    "সরাসরি একজন মানুষের সাথে কথা বলতে চাই" => "human_agent",
    "বাংলাতে উত্তর দিবেন" => "language_preference",
    "আপনি কি মানুষ নাকি বট" => "bot_identity",
    "অন্য কোনো অপশন দেখান" => "alternative_product",
    "এইগুলা আমার ভালো লাগেনি" => "reject_recommendations",
    "আমার আগের অর্ডারগুলো দেখতে চাই" => "order_history",
    "পণ্যটা ফেরত দিতে চাই" => "return_request"
  }.freeze

  test "keeps 20 to 50 balanced multilingual examples per intent" do
    CompactIntentClassifier.examples.each do |intent, examples|
      assert_includes 20..50, examples.size, intent
      assert examples.any? { |example| example.match?(/\p{Bengali}/) }, "#{intent} has no Bangla example"
      assert examples.any? { |example| example.ascii_only? }, "#{intent} has no English or Banglish example"
    end
  end

  test "meets held-out multilingual accuracy and coverage thresholds" do
    results = HELD_OUT_CASES.map do |text, expected|
      [ expected, classify(text)&.intent ]
    end
    covered = results.count { |_expected, actual| actual.present? }
    correct = results.count { |expected, actual| expected == actual }

    assert_operator covered.fdiv(results.size), :>=, 0.80, "coverage: #{results.inspect}"
    assert_operator correct.fdiv(results.size), :>=, 0.72, "accuracy: #{results.inspect}"
  end

  test "leaves a checkout value to the deterministic order flow" do
    assert_nil classify("10 ML", status: :collecting_variant)
    assert_nil classify("100 ML ache?", status: :collecting_variant)
    assert_nil classify("bigger size", status: :collecting_variant)
    assert_nil classify("01712345678", status: :collecting_phone)
  end

  private

  def classify(content, status: :collecting_product)
    conversation = Conversation.create!(channel: "facebook", external_customer_id: SecureRandom.uuid)
    message = conversation.messages.create!(sender_type: :customer, content: content)
    order = conversation.create_pending_order!(status: status)
    CompactIntentClassifier.new(message: message, pending_order: order).classify.interpretation
  end
end
