require "test_helper"

class Api::BusinessManualModeTest < ActionDispatch::IntegrationTest
  setup do
    @business = Business.create!(name: "Manual API", slug: "manual-api")
    @other = Business.create!(name: "Other API", slug: "manual-other-api")
    token, digest = User.issue_token
    @user = @business.users.create!(name: "Owner", email: "owner@manual-api.test", role: "owner", api_token_digest: digest)
    @headers = { "Authorization" => "Bearer #{token}" }
  end

  test "owner pauses only their business and profile updates preserve pause settings" do
    patch api_business_path, params: { business: { automation_paused: true } }, headers: @headers, as: :json
    assert_response :success
    assert JSON.parse(response.body).fetch("automation_paused")
    assert @business.reload.automation_paused?
    assert_not @other.reload.automation_paused?
    paused_at = @business.settings[Constants::Automation::PAUSED_AT]
    patch api_business_path, params: { business: { settings: { usd_exchange_rate: "120", automation_paused: false }, name: "Updated" } }, headers: @headers, as: :json
    assert_response :success
    assert @business.reload.automation_paused?
    assert_equal paused_at, @business.settings[Constants::Automation::PAUSED_AT]
    patch api_business_path, params: { business: { automation_paused: false } }, headers: @headers, as: :json
    assert_response :success
    assert_not @business.reload.automation_paused?
  end

  test "sales agents cannot pause and invalid boolean values are rejected" do
    @user.update!(role: "sales_agent")
    patch api_business_path, params: { business: { automation_paused: true } }, headers: @headers, as: :json
    assert_response :forbidden
    @user.update!(role: "owner")
    patch api_business_path, params: { business: { automation_paused: "false" } }, headers: @headers, as: :json
    assert_response :unprocessable_entity
    assert_not @business.reload.automation_paused?
  end

  test "staff can reply without individual takeover and cannot resume AI from a paused chat" do
    @business.update!(automation_paused: true)
    conversation = @business.conversations.create!(channel: "facebook", external_customer_id: "manual-customer")
    get api_conversation_path(conversation), headers: @headers
    assert_response :success
    assert JSON.parse(response.body).fetch("automation_paused")
    post reply_api_conversation_path(conversation), params: { content: "A human is replying" }, headers: @headers, as: :json
    assert_response :created
    assert_equal "seller", conversation.messages.last.sender_type
    assert_predicate conversation.reload, :active?
    post resume_api_conversation_path(conversation), headers: @headers
    assert_response :unprocessable_entity
  end
end
