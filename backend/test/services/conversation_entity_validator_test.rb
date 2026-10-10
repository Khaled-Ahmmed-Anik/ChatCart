require "test_helper"

class ConversationEntityValidatorTest < ActiveSupport::TestCase
  test "rejects invented entities while preserving explicitly stated values" do
    result = validate("Cotton Shirt two pieces den", product_name: "Canvas Bag", quantity: 2, address: "Dhaka")
    assert_equal({ "quantity" => 2 }, result.entities.to_h)
  end

  test "size and timing values do not support a proposed quantity" do
    [ "30 ml chai", "two days delivery", "2 kg rice", "2 taka" ].each do |content|
      result = validate(content, quantity: content.start_with?("30") ? 30 : 2)
      assert_empty result.entities, content
    end
  end

  test "Bengali digits and formatted phones support explicit entities" do
    result = validate("২ pieces, 01712 345678", quantity: 2, phone: "01712345678")
    assert_equal 2, result.entities[:quantity]
    assert_equal "01712345678", result.entities[:phone]
  end

  private

  def validate(content, **entities)
    interpretation = AiIntentClassifier::Result.new(
      intent: "select_product", confidence: 0.99, entities: entities.with_indifferent_access,
      language: "banglish", sentiment: "neutral", needs_clarification: false, possible_intents: []
    )
    ConversationEntityValidator.call(interpretation, content)
  end
end
