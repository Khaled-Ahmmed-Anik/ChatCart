require "test_helper"

class ConversationTextNormalizerTest < ActiveSupport::TestCase
  test "preserves Bengali vowel marks and normalizes Bengali digits" do
    assert_equal "পরিমাণ 2টা করুন", ConversationTextNormalizer.call("পরিমাণ ২টা করুন")
  end
end
