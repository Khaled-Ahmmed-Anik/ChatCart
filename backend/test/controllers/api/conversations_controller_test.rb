require "test_helper"

class Api::ConversationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @business = Business.create!(name: "Alpha", slug: "alpha-conversations", category: "retail")
    token, digest = User.issue_token
    @business.users.create!(name: "Owner", email: "owner@alpha-conversations.test", role: "owner", api_token_digest: digest)
    @headers = { "Authorization" => "Bearer #{token}" }
  end

  test "returns the cached Messenger customer name and external id" do
    conversation = @business.conversations.create!(
      channel: "facebook",
      external_customer_id: "psid-123",
      conversation_state: { customer_profile: { name: "Khaled Anik", source: "messenger" } }
    )

    get api_conversations_path, headers: @headers

    assert_response :success
    item = JSON.parse(response.body).find { |record| record.fetch("id") == conversation.id }
    assert_equal "Khaled Anik", item.fetch("customer_name")
    assert_equal "psid-123", item.fetch("external_customer_id")
  end

  test "falls back to the latest captured order name" do
    conversation = @business.conversations.create!(channel: "facebook", external_customer_id: "psid-456")
    conversation.pending_orders.create!(customer_name: "Order Customer")

    get api_conversation_path(conversation), headers: @headers

    assert_response :success
    assert_equal "Order Customer", JSON.parse(response.body).fetch("customer_name")
  end
end
