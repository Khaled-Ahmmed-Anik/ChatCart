require "test_helper"

class ConversationEvaluationSuiteTest < ActiveSupport::TestCase
  test "loads unique multilingual sector-neutral cases" do
    cases = ConversationEvaluationSuite.load

    assert_operator cases.size, :>=, 15
    assert_equal cases.size, cases.map(&:id).uniq.size
    assert_equal %w[banglish bengali english], cases.map(&:locale).uniq.sort
    assert_includes cases.flat_map(&:tags), "fashion"
    assert_includes cases.flat_map(&:tags), "food"
    assert_includes cases.flat_map(&:tags), "electronics"
  end

  test "rejects duplicate ids" do
    first = ConversationEvaluationSuite::Case.new(
      id: "duplicate", message: "hello", expected_intent: "greeting", locale: "english",
      pending_order_status: "collecting_product", tags: []
    )

    error = assert_raises(ArgumentError) do
      ConversationEvaluationSuite.send(:validate!, [ first, first ])
    end

    assert_match "duplicate evaluation ids", error.message
  end
end
