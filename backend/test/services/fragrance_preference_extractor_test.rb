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

  test "captures negative preferences, softer projection, and budget" do
    preferences = FragrancePreferenceExtractor.new(
      "Office er jonno fresh chai, sweet jeno na hoy, too strong na, budget 500"
    ).call

    assert_includes preferences["scent_families"], "fresh"
    assert_includes preferences["occasions"], "office"
    assert_includes preferences["avoid_scent_families"], "sweet"
    assert_not_includes preferences["scent_families"], "sweet"
    assert_equal "moderate", preferences["maximum_projection"]
    assert_equal 500.to_d, preferences["maximum_price"]
  end

  test "normalizes common oud spelling variations" do
    %w[oudy oudi oody oddy ody].each do |spelling|
      preferences = FragrancePreferenceExtractor.new("I need something #{spelling}").call

      assert_includes preferences["scent_families"], "oud", spelling
    end
  end

  test "recognizes comparative recommendation refinements" do
    preferences = FragrancePreferenceExtractor.new("Ektu cheaper but stronger kichu chai").call

    assert_equal "lower", preferences["price_direction"]
    assert_equal "stronger", preferences["projection_preference"]
    assert FragrancePreferenceExtractor.new("Ektu cheaper but stronger kichu chai").refinement?
  end
end
