require "test_helper"

module Admin
  class BusinessesControllerTest < ActionDispatch::IntegrationTest
    PASSWORD = "Strong-Test-Password-2026!"

    setup do
      administrator = PlatformAdministrator.create!(
        name: "Platform Admin", email: "admin@example.com", password: PASSWORD
      )
      @admin_token = AuthSession.issue!(actor: administrator).first
      @business = Business.create!(name: "Test Business", slug: "test-business")
    end

    test "platform administrators can suspend and reactivate a business" do
      update_status("suspended", token: @admin_token)

      assert_response :success
      assert_equal "suspended", @business.reload.status

      update_status("active", token: @admin_token)

      assert_response :success
      assert_equal "active", @business.reload.status
    end

    test "disabling a business through the API revokes its user sessions" do
      _legacy_token, digest = User.issue_token
      user = @business.users.create!(
        name: "Owner", email: "owner@example.com", role: "owner", api_token_digest: digest, password: PASSWORD
      )
      user_token, session = AuthSession.issue!(actor: user)

      update_status("disabled", token: @admin_token)

      assert_response :success
      assert session.reload.revoked?
      get api_business_path, headers: authorization(user_token)
      assert_response :unauthorized
    end

    test "business users cannot change business lifecycle status" do
      legacy_token, digest = User.issue_token
      @business.users.create!(
        name: "Owner", email: "owner@example.com", role: "owner", api_token_digest: digest, password: PASSWORD
      )

      update_status("disabled", token: legacy_token)

      assert_response :unauthorized
      assert_equal "active", @business.reload.status
    end

    test "invalid lifecycle statuses are rejected" do
      update_status("deleted", token: @admin_token)

      assert_response :unprocessable_entity
      assert_equal "active", @business.reload.status
      assert JSON.parse(response.body).dig("errors", "status").present?
    end

    private

    def update_status(status, token:)
      patch admin_business_path(@business), params: { business: { status: status } },
        headers: authorization(token), as: :json
    end

    def authorization(token)
      { "Authorization" => "Bearer #{token}" }
    end
  end
end
