require "test_helper"

class BusinessTest < ActiveSupport::TestCase
  PASSWORD = "Strong-Test-Password-2026!"

  test "suspending a business revokes every user session" do
    business = create_business(slug: "suspended-business")
    sessions = 2.times.map { |index| AuthSession.issue!(actor: create_user(business, index: index)).last }

    business.update!(status: "suspended")

    sessions.each do |session|
      session.reload
      assert session.revoked?
      assert_equal AuthSession::BUSINESS_INACTIVE_REASON, session.revocation_reason
    end
  end

  test "disabling a business revokes every user session" do
    business = create_business(slug: "disabled-business")
    session = AuthSession.issue!(actor: create_user(business, index: 1)).last

    business.update!(status: "disabled")

    assert session.reload.revoked?
    assert_equal AuthSession::BUSINESS_INACTIVE_REASON, session.revocation_reason
  end

  test "changing one business does not revoke another business session" do
    disabled_business = create_business(slug: "disabled-business")
    active_business = create_business(slug: "active-business")
    disabled_session = AuthSession.issue!(actor: create_user(disabled_business, index: 1)).last
    active_token, active_session = AuthSession.issue!(actor: create_user(active_business, index: 2))

    disabled_business.update!(status: "disabled")

    assert disabled_session.reload.revoked?
    assert_not active_session.reload.revoked?
    assert_equal active_session, AuthSession.authenticate(active_token)
  end

  test "reactivating a business does not restore revoked sessions" do
    business = create_business(slug: "reactivated-business")
    token, session = AuthSession.issue!(actor: create_user(business, index: 1))

    business.update!(status: "disabled")
    business.update!(status: "active")

    assert session.reload.revoked?
    assert_nil AuthSession.authenticate(token)
  end

  private

  def create_business(slug:)
    Business.create!(name: slug.humanize, slug: slug)
  end

  def create_user(business, index:)
    _token, digest = User.issue_token
    business.users.create!(
      name: "Owner #{index}", email: "owner-#{business.slug}-#{index}@example.com", role: "owner",
      api_token_digest: digest, password: PASSWORD
    )
  end
end
