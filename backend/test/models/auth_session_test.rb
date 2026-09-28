require "test_helper"

class AuthSessionTest < ActiveSupport::TestCase
  test "active sessions authenticate" do
    token, session = AuthSession.issue!(actor: user)

    assert_equal session, AuthSession.authenticate(token)
    assert_not session.revoked?
  end

  test "expired sessions do not authenticate" do
    token, session = AuthSession.issue!(actor: user)
    session.update!(expires_at: 1.minute.ago)

    assert_nil AuthSession.authenticate(token)
  end

  test "revoked sessions do not authenticate and retain a safe reason" do
    token, session = AuthSession.issue!(actor: user)

    session.revoke!(reason: "account_disabled")

    assert session.revoked?
    assert_equal "account_disabled", session.revocation_reason
    assert_nil AuthSession.authenticate(token)
  end

  private

  def user
    @user ||= begin
      business = Business.create!(name: "Session Test", slug: "session-test")
      _token, digest = User.issue_token
      business.users.create!(
        name: "Owner", email: "session-owner@example.com", role: "owner", api_token_digest: digest,
        password: "Strong-Test-Password-2026!"
      )
    end
  end
end
