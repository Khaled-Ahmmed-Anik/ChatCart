require "test_helper"

class BusinessManualModeTest < ActiveSupport::TestCase
  setup do
    @business = Business.create!(name: "Manual Shop", slug: "manual-shop")
  end

  test "pause records new and existing chats without feedback or order replies" do
    existing = @business.conversations.create!(channel: "facebook", external_customer_id: "existing")
    @business.update!(automation_paused: true)
    assert_no_difference [ -> { PendingOrder.count }, -> { Order.count } ] do
      %w[existing new].each do |customer|
        result = CustomerMessageRecorder.new(business: @business, channel: "facebook", external_customer_id: customer, content: "helpful").record
        assert_nil result.bot_reply
        assert_equal :awaiting_human, result.outcome
        assert_equal "helpful", result.message.content
      end
    end
    assert_predicate existing.reload, :active?
    assert_equal 2, @business.conversations.count
  end

  test "other businesses keep responding and the paused business remains active" do
    @business.update!(automation_paused: true)
    other = Business.create!(name: "Other", slug: "other-manual-shop")
    result = CustomerMessageRecorder.new(business: other, channel: "facebook", external_customer_id: "other", content: "helpful").record
    assert result.bot_reply
    assert_predicate @business, :active?
    assert_not other.automation_paused?
  end

  test "resume preserves individual takeovers and suppresses old queued input" do
    conversation = @business.conversations.create!(channel: "facebook", external_customer_id: "individual", status: :handed_over)
    @business.update!(automation_paused: true)
    received_at = Time.current
    travel 1.second do
      @business.update!(automation_paused: false)
      old = CustomerMessageRecorder.new(business: @business, channel: "facebook", external_customer_id: "old", content: "helpful", received_at: received_at).record
      assert_nil old.bot_reply
      fresh = CustomerMessageRecorder.new(business: @business, channel: "facebook", external_customer_id: "fresh", content: "helpful").record
      assert fresh.bot_reply
      assert_not @business.blocks_automated_reply?(fresh.bot_reply)
    end
    assert_predicate conversation.reload, :handed_over?
  end

  test "stale generated bot replies remain blocked after resume but sellers do not" do
    conversation = @business.conversations.create!(channel: "facebook", external_customer_id: "queue")
    queued = conversation.messages.create!(sender_type: :bot, content: "Old bot")
    @business.update!(automation_paused: true)
    in_flight = conversation.messages.create!(sender_type: :bot, content: "Stale generated reply")
    seller = conversation.messages.create!(sender_type: :seller, content: "Human reply")
    @business.update!(automation_paused: false)
    assert @business.blocks_automated_reply?(queued)
    assert @business.blocks_automated_reply?(in_flight)
    assert_not @business.blocks_automated_reply?(seller)
  end

  test "both outbound workers skip queued bots without contacting providers" do
    conversation = @business.conversations.create!(channel: "facebook", external_customer_id: "outbound")
    message = conversation.messages.create!(sender_type: :bot, content: "queued")
    event = @business.messenger_webhook_events.create!(event_type: "customer_text", sender_id: "outbound", payload: {})
    delivery = MessengerDelivery.create!(messenger_webhook_event: event, message: message, recipient_id: "outbound")
    whatsapp_event = WhatsappWebhookEvent.create!(business: @business, event_type: "customer_text", sender_id: "outbound", phone_number_id: "phone", payload: {})
    whatsapp_delivery = WhatsappDelivery.create!(whatsapp_webhook_event: whatsapp_event, message: message, recipient_id: "outbound", phone_number_id: "phone")
    @business.update!(automation_paused: true)
    @business.update!(automation_paused: false)
    SendMessengerReplyJob.perform_now(delivery)
    SendWhatsappReplyJob.perform_now(whatsapp_delivery)
    [ delivery, whatsapp_delivery ].each do |item|
      assert_equal "skipped", item.reload.status
      assert_equal 0, item.attempts
      assert_equal "business_automation_paused", item.last_error
    end
  end

  test "a batch spanning resume records old text separately from new automatic input" do
    @business.update!(automation_paused: true)
    old = @business.messenger_webhook_events.create!(event_type: "customer_text", sender_id: "mixed", status: "received", payload: { message: { text: "OLD MANUAL MESSAGE" } })
    travel 2.seconds do
      @business.update!(automation_paused: false)
      fresh = @business.messenger_webhook_events.create!(event_type: "customer_text", sender_id: "mixed", status: "received", payload: { message: { text: "helpful" } })
      ProcessMessengerEventJob.perform_now(fresh)
      conversation = @business.conversations.find_by!(external_customer_id: "mixed")
      assert_equal [ "OLD MANUAL MESSAGE", "helpful" ], conversation.messages.customer.order(:id).pluck(:content)
      assert_equal 1, conversation.messages.bot.count
      assert_equal "processed", old.reload.status
      assert_equal "processed", fresh.reload.status
    end
  end
end
