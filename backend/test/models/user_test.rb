require "test_helper"

class UserTest < ActiveSupport::TestCase
  PASSWORD = "Strong-Test-Password-2026!"

  test "deactivating a user revokes all of their active sessions" do
    user = create_user(email: "disabled@example.com")
    sessions = 2.times.map { AuthSession.issue!(actor: user).last }

    user.update!(active: false)

    sessions.each do |session|
      session.reload
      assert session.revoked?
      assert_equal AuthSession::ACCOUNT_DISABLED_REASON, session.revocation_reason
    end
  end

  test "deactivating a user does not revoke another user's sessions" do
    disabled_user = create_user(email: "disabled@example.com")
    active_user = create_user(email: "active@example.com")
    disabled_session = AuthSession.issue!(actor: disabled_user).last
    active_token, active_session = AuthSession.issue!(actor: active_user)

    disabled_user.update!(active: false)

    assert disabled_session.reload.revoked?
    assert_not active_session.reload.revoked?
    assert_equal active_session, AuthSession.authenticate(active_token)
  end

  test "reactivating a user does not restore revoked sessions" do
    user = create_user(email: "reactivated@example.com")
    token, session = AuthSession.issue!(actor: user)

    user.update!(active: false)
    user.update!(active: true)

    assert session.reload.revoked?
    assert_nil AuthSession.authenticate(token)
  end

  private

  def create_user(email:)
    business = Business.create!(name: email, slug: email.split("@").first.tr("_", "-"))
    _token, digest = User.issue_token
    business.users.create!(
      name: "Owner", email: email, role: "owner", api_token_digest: digest, password: PASSWORD
    )
  end
end
