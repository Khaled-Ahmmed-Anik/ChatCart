class CatalogueCustomerPreferences
  def self.remember!(conversation, text)
    state = conversation.conversation_state.to_h
    preferences = state["shopping_preferences"].to_h
    devices = text.to_s.scan(/\b(?:Samsung\s+[a-z0-9]+|iPhone\s+\d+|Pixel\s+\d+|OnePlus\s+\d+)\b/i)
    preferences["device"] = devices.last if devices.any?
    preferences["use_case"] = "calls" if text.to_s.match?(/\bcalls?\b/i)
    budget = CatalogueBudgetParser.call(text)
    preferences = preferences.except("minimum_price", "maximum_price").merge(budget) if budget.any?
    conversation.update!(conversation_state: state.merge("shopping_preferences" => preferences))
  end
end
