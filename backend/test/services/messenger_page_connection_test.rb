require "test_helper"

class MessengerPageConnectionTest < ActiveSupport::TestCase
  test "only resolves the originating active page within the event business" do
    business = Business.default
    connection = business.channel_connections.create!(channel: "facebook", external_account_id: "page-origin", status: "active", access_token: "origin-token")
    event = business.messenger_webhook_events.create!(event_type: "customer_text", sender_id: "customer", payload: { chatcart_page_id: "page-origin" }, status: "received")
    assert_equal connection, MessengerPageConnection.for_event(event)
    connection.update!(status: "disconnected")
    assert_nil MessengerPageConnection.for_event(event)
    connection.update!(status: "active", business: Business.create!(name: "Other", slug: "other-page-owner"))
    assert_nil MessengerPageConnection.for_event(event)
    event.update!(payload: {})
    assert_nil MessengerPageConnection.for_event(event)
  end
end
