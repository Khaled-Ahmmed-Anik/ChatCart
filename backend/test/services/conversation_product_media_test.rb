require "test_helper"

class ConversationProductMediaTest < ActiveSupport::TestCase
  setup do
    @business = Business.create!(name: "Media Shop", slug: "media-shop", category: "electronics")
    @product = @business.products.create!(name: "Travel Charger", price: 700, stock_quantity: 10,
      image_urls: [ "https://cdn.shop.test/catalogue.jpg" ],
      product_attributes: { "catalogue_media" => [
        { "kind" => "image", "authenticity" => "actual", "url" => "https://cdn.shop.test/actual.jpg" },
        { "kind" => "video", "authenticity" => "actual", "url" => "https://cdn.shop.test/demo.mp4" }
      ], "reference_urls" => [ "https://www.facebook.com/shop/posts/123" ] })
    @conversation = @business.conversations.create!(channel: "facebook", external_customer_id: "media-test")
    @order = @conversation.create_pending_order!(product: @product, quantity: 2, status: :collecting_name)
  end

  test "actual photos and video requests use separate saved attachments without changing checkout" do
    [ [ "real photo den", "image", "actual.jpg" ], [ "actual videos please", "video", "demo.mp4" ], [ "আসল ছবি দিন", "image", "actual.jpg" ] ].each do |text, kind, file|
      result = record(text)
      assert_equal :product_media_requested, result.outcome
      attachment = result.bot_reply.metadata.fetch("attachments").sole
      assert_equal kind, attachment["type"]
      assert attachment["url"].end_with?(file)
      assert_equal @product.id, @order.reload.product_id
      assert_equal 2, @order.quantity
      assert_predicate @order, :collecting_name?
      assert_empty @business.orders
    end
  end

  test "real media never falls back to promotional catalogue images" do
    @product.update!(product_attributes: {})
    real = record("real photo please")
    assert_empty real.bot_reply.metadata["attachments"]
    ordinary = record("photo please")
    assert_equal "https://cdn.shop.test/catalogue.jpg", ordinary.bot_reply.metadata["attachments"].sole["url"]
    assert_includes ordinary.bot_reply.content, "not verified"
    assert_empty record("video please").bot_reply.metadata["attachments"]
  end

  test "matching Facebook reference normalizes tracking but preserves post identity" do
    result = record("https://m.facebook.com/shop/posts/123/?fbclid=tracking")
    assert_includes result.bot_reply.content, @product.name
    assert_equal @product.name, @conversation.reload.conversation_state["last_referenced_product"]
    assert_equal 2, @order.reload.quantity
    unknown = record("https://facebook.com/shop/posts/124")
    assert_includes unknown.bot_reply.content, "screenshot"
    assert_empty unknown.bot_reply.metadata["attachments"]
    assert_not_equal ProductReferenceUrl.normalize("https://facebook.com/photo.php?fbid=1"),
      ProductReferenceUrl.normalize("https://facebook.com/photo.php?fbid=2")
  end

  test "unknown links and another business references cannot resolve to the selected product" do
    other = Business.create!(name: "Other Media", slug: "other-media")
    other.products.create!(name: "Secret", price: 1, stock_quantity: 1, source_url: "https://facebook.com/secret/posts/1")
    reply = record("real photo https://facebook.com/secret/posts/1").bot_reply
    assert_empty reply.metadata["attachments"]
    assert_includes reply.content, "screenshot"
    assert_empty record("Galaxy Phone real photo please").bot_reply.metadata["attachments"]
    @product.update!(active: false)
    assert_empty record("Travel Charger real photo").bot_reply.metadata["attachments"]
  end

  test "variant requests never substitute another variant or generic media" do
    @product.product_variants.create!(name: "Black", price: 700, stock_quantity: 10)
    @product.product_variants.create!(name: "White", price: 700, stock_quantity: 10)
    attributes = @product.product_attributes
    attributes["catalogue_media"] << { "kind" => "image", "authenticity" => "actual", "variant" => "Black", "url" => "https://cdn.shop.test/black.jpg" }
    @product.update!(product_attributes: attributes)
    assert_equal "https://cdn.shop.test/black.jpg", record("Black real photo please").bot_reply.metadata["attachments"].sole["url"]
    assert_empty record("White real photo please").bot_reply.metadata["attachments"]
    assert_empty record("Red real photo please").bot_reply.metadata["attachments"]
  end

  test "invalid media cannot be saved and duplicate references require clarification" do
    @product.product_attributes = { "catalogue_media" => [ { "kind" => "video", "authenticity" => "actual", "url" => "http://localhost/private" } ] }
    refute @product.valid?
    @product.product_attributes = { "catalogue_media" => [ { "kind" => "video", "authenticity" => "actual", "url" => "https://facebook.com/watch/123" } ] }
    refute @product.valid?
    @product.reload
    @business.products.create!(name: "Other product", price: 1, stock_quantity: 1, source_url: "https://facebook.com/shop/posts/123")
    result = record("https://facebook.com/shop/posts/123")
    assert_includes result.bot_reply.content, "Which product"
    assert_empty result.bot_reply.metadata["attachments"]
  end

  test "automation pause suppresses media replies" do
    @business.update!(automation_paused: true)
    assert_nil record("real photo please").bot_reply
  end

  test "other channels do not promise unsupported attachments" do
    @conversation.update!(channel: "whatsapp")
    message = @conversation.messages.create!(sender_type: :customer, content: "real photo please")
    result = ConversationProductMedia.new(conversation: @conversation, message: message).call
    assert_empty result.attachments
    assert_includes result.content, "Messenger"
    assert_equal 2, @order.reload.quantity
  end

  test "media replies are bounded and ordinary preferences exclude media metadata" do
    items = 5.times.map { |index| { "kind" => "image", "authenticity" => "actual", "url" => "https://cdn.shop.test/#{index}.jpg" } }
    @product.update!(product_attributes: { "catalogue_media" => items, "reference_urls" => [ "https://facebook.com/posts/1" ], "material" => "plastic" })
    assert_equal Constants::ProductMedia::MAX_ATTACHMENTS, record("real photo please").bot_reply.metadata["attachments"].size
    keys = CataloguePreferenceExtractor.new("charger", business: @business).available_attributes.keys
    assert_includes keys, "material"
    assert_not_includes keys, Constants::ProductMedia::KEY
    assert_not_includes keys, Constants::ProductMedia::LINKS_KEY
  end

  private

  def record(text)
    CustomerMessageRecorder.new(business: @business, channel: "facebook", external_customer_id: "media-test", content: text).record
  end
end
