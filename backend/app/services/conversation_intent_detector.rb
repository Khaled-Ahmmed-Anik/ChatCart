class ConversationIntentDetector
  def initialize(content)
    @content = content.to_s.downcase.squish
  end

  def new_order?
    content.match?(/\b(new|another|fresh)\s+order\b/) ||
      content.match?(/\bre-?order\b/) ||
      content.match?(/\b(notun|noton|natun|nothun)\s+order\b/) ||
      content.match?(/\babar\s+order\b/) ||
      content.match?(/\border\s+(korbo|korte\s+chai|kora\s+jabe|korte\s+parbo)\b/) ||
      content.match?(/\A(restart|start over|order again)[?!. ]*\z/)
  end

  def order_details?
    return false if content.match?(/\b(change|update|edit)\b/)

    content.match?(/\b(order details|order summary|show (my )?order|my order details)\b/) ||
      content.match?(/\bamar\s+order\b.*\b(details|ki|silo|chilo|chhilo)\b/) ||
      content.match?(/\border\s+(ta|details)\s+ki\s+(silo|chilo|chhilo)\b/)
  end

  private

  attr_reader :content
end
