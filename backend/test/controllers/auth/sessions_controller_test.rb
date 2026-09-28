require "test_helper"

class Auth::SessionsControllerTest < ActionDispatch::IntegrationTest
  PASSWORD = "Strong-Test-Password-2026!"

  test "business user signs in with email and password and receives an expiring session" do
    business = Business.create!(name: "Alpha", slug: "alpha")
    user = create_user(business, email: "Owner@Example.com")

    post auth_login_path, params: { email: "owner@example.com", password: PASSWORD }, as: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "business_user", body["actor_type"]
    assert_equal business.id, body.dig("business", "id")
    assert body["token"].present?
    assert_operator Time.iso8601(body["expires_at"]), :>, Time.current

    get api_business_path, headers: { "Authorization" => "Bearer #{body['token']}" }
    assert_response :success
    assert_equal user.business.name, JSON.parse(response.body)["name"]
  end

  test "invalid business credentials are rejected without revealing which field failed" do
    business = Business.create!(name: "Alpha", slug: "alpha")
    create_user(business, email: "owner@example.com")

    post auth_login_path, params: { email: "owner@example.com", password: "wrong-password-value" }, as: :json

    assert_response :unauthorized
    assert_equal "Invalid email or password", JSON.parse(response.body)["error"]
  end

  test "platform administrator signs in and can manage businesses" do
    administrator = PlatformAdministrator.create!(
      name: "Platform Admin", email: "admin@chatcart.test", password: PASSWORD
    )

    post auth_admin_login_path,
      params: { email: administrator.email, password: PASSWORD }, as: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "platform_administrator", body["actor_type"]

    get admin_businesses_path, headers: { "Authorization" => "Bearer #{body['token']}" }
    assert_response :success
  end

  test "logout revokes a business session" do
    business = Business.create!(name: "Alpha", slug: "alpha")
    create_user(business, email: "owner@example.com")
    post auth_login_path, params: { email: "owner@example.com", password: PASSWORD }, as: :json
    token = JSON.parse(response.body)["token"]

    delete auth_logout_path, headers: { "Authorization" => "Bearer #{token}" }
    assert_response :no_content

    get api_business_path, headers: { "Authorization" => "Bearer #{token}" }
    assert_response :unauthorized
  end

  test "inactive business users cannot create or continue sessions" do
    business = Business.create!(name: "Alpha", slug: "alpha")
    user = create_user(business, email: "owner@example.com")
    token, = AuthSession.issue!(actor: user)
    user.update!(active: false)

    post auth_login_path, params: { email: user.email, password: PASSWORD }, as: :json
    assert_response :unauthorized

    get api_business_path, headers: { "Authorization" => "Bearer #{token}" }
    assert_response :unauthorized
  end

  test "inactive platform administrators cannot create or continue sessions" do
    administrator = PlatformAdministrator.create!(
      name: "Platform Admin", email: "inactive-admin@chatcart.test", password: PASSWORD
    )
    token, = AuthSession.issue!(actor: administrator)
    administrator.update!(active: false)

    post auth_admin_login_path, params: { email: administrator.email, password: PASSWORD }, as: :json
    assert_response :unauthorized

    get admin_businesses_path, headers: { "Authorization" => "Bearer #{token}" }
    assert_response :unauthorized
  end

  test "users of suspended businesses cannot create or continue sessions" do
    business = Business.create!(name: "Alpha", slug: "alpha")
    user = create_user(business, email: "owner@example.com")
    token, = AuthSession.issue!(actor: user)
    business.update!(status: "suspended")

    post auth_login_path, params: { email: user.email, password: PASSWORD }, as: :json
    assert_response :unauthorized

    get api_business_path, headers: { "Authorization" => "Bearer #{token}" }
    assert_response :unauthorized
  end

  test "users of disabled businesses cannot use sessions or legacy API tokens" do
    business = Business.create!(name: "Alpha", slug: "alpha")
    legacy_token, digest = User.issue_token
    user = business.users.create!(
      name: "Owner", email: "owner@example.com", role: "owner", api_token_digest: digest, password: PASSWORD
    )
    session_token, = AuthSession.issue!(actor: user)
    business.update!(status: "disabled")

    post auth_login_path, params: { email: user.email, password: PASSWORD }, as: :json
    assert_response :unauthorized

    get api_business_path, headers: { "Authorization" => "Bearer #{session_token}" }
    assert_response :unauthorized

    get api_business_path, headers: { "Authorization" => "Bearer #{legacy_token}" }
    assert_response :unauthorized
  end

  private

  def create_user(business, email:)
    _token, digest = User.issue_token
    business.users.create!(
      name: "Owner", email: email, role: "owner", api_token_digest: digest, password: PASSWORD
    )
  end
end
