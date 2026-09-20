require "test_helper"

class ConversationAddressPreferenceTest < ActiveSupport::TestCase
  test "detects directly used English Banglish and Bengali forms of address" do
    assert_equal "bhai", ConversationAddressPreference.detect("Bhai, price koto?")
    assert_equal "apu", ConversationAddressPreference.detect("hello apu")
    assert_equal "sir", ConversationAddressPreference.detect("thank you sir")
    assert_equal "ma'am", ConversationAddressPreference.detect("Hi ma'am, I need help")
    assert_equal "bhai", ConversationAddressPreference.detect("ভাই, এটা আছে?")
  end

  test "does not infer an address preference from a reference to another person" do
    assert_nil ConversationAddressPreference.detect("My brother wants to order this")
    assert_nil ConversationAddressPreference.detect("This is for my sister")
  end
end
