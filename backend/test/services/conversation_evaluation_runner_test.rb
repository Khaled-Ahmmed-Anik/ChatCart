require "test_helper"

class ConversationEvaluationRunnerTest < ActiveSupport::TestCase
  test "reports aggregate, locale, tag, and failure metrics" do
    report = ConversationEvaluationRunner.new.call

    assert_equal ConversationEvaluationSuite.load.size, report[:total]
    assert report[:passing], report[:failures].inspect
    assert_operator report[:accuracy], :>=, ConversationEvaluationRunner::MINIMUM_ACCURACY
    assert_operator report[:coverage], :>=, ConversationEvaluationRunner::MINIMUM_COVERAGE
    assert_equal %w[banglish bengali english], report[:by_locale].keys.sort
    assert report[:by_tag].key?("order")
    assert report[:failures].all? { |failure| failure.key?(:score) }
  end

  test "does not persist evaluation conversations or orders" do
    assert_no_difference [ "Conversation.count", "PendingOrder.count", "Message.count" ] do
      ConversationEvaluationRunner.new.call
    end
  end
end
