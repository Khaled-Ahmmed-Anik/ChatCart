require "test_helper"

class FragrancePreferenceExtractorTest < ActiveSupport::TestCase
  test "extracts and accumulates guided fragrance preferences" do
    first = FragrancePreferenceExtractor.new("I want a combo").call
    second = FragrancePreferenceExtractor.new("for him, fresh and woody for office").call(existing: first)

    assert_equal "combo", second["format"]
    assert_equal "men", second["audience"]
    assert_equal %w[fresh woody], second["scent_families"]
    assert_equal [ "office" ], second["occasions"]
  end
end
