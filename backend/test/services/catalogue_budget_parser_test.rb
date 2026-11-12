require "test_helper"

class CatalogueBudgetParserTest < ActiveSupport::TestCase
  test "money cues select the budget rather than model, wattage, capacity or quantity" do
    [ "45W charger under 2,000", "EQ34 earbuds budget 2000", "iPhone 15 charger within 2000", "2 bottles 30 ml under 2000", "২০০০ টাকার মধ্যে", "2000 er moddhe" ].each do |text|
      assert_equal 2000.to_d, CatalogueBudgetParser.call(text)["maximum_price"], text
    end
  end

  test "ranges do not pick specifications" do
    assert_equal({ "minimum_price" => 1000.to_d, "maximum_price" => 2000.to_d }, CatalogueBudgetParser.call("45W charger 1000 to 2000"))
  end

  test "technical numbers without money cues do not become budgets" do
    [ "iPhone 15", "45W charger", "EQ34", "budget 45W charger" ].each do |text|
      assert_empty CatalogueBudgetParser.call(text), text
    end
  end
end
