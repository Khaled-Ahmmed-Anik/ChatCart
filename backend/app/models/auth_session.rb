require "digest"

class AuthSession < ApplicationRecord
  DEFAULT_LIFETIME = 12.hours
  ACCOUNT_DISABLED_REASON = "account_disabled"
  BUSINESS_INACTIVE_REASON = "business_inactive"

  belongs_to :user, optional: true
  belongs_to :platform_administrator, optional: true

  validates :token_digest, :expires_at, presence: true
  validate :exactly_one_actor

  scope :active, -> { where(revoked_at: nil).where("auth_sessions.expires_at > ?", Time.current) }

  def self.issue!(actor:, ip_address: nil, user_agent: nil)
    token = SecureRandom.urlsafe_base64(48)
    attributes = {
      token_digest: digest(token), expires_at: DEFAULT_LIFETIME.from_now,
      ip_address: ip_address, user_agent: user_agent.to_s.first(500)
    }
    attributes[actor.is_a?(User) ? :user : :platform_administrator] = actor
    session = create!(attributes)
    [ token, session ]
  end

  def self.authenticate(token)
    return if token.blank?

    session = active.includes(:user, :platform_administrator).find_by(token_digest: digest(token))
    return unless session&.actor&.authentication_allowed?

    session.tap { |authenticated| authenticated.touch(:last_used_at) }
  end

  def actor
    user || platform_administrator
  end

  def revoked?
    revoked_at.present?
  end

  def revoke!(reason: nil)
    update!(revoked_at: Time.current, revocation_reason: reason)
  end

  def self.revoke_all!(reason:)
    update_all(revoked_at: Time.current, revocation_reason: reason, updated_at: Time.current)
  end

  def self.digest(token)
    Digest::SHA256.hexdigest(token)
  end

  private

  def exactly_one_actor
    errors.add(:base, "must belong to exactly one actor") if user.present? == platform_administrator.present?
  end
end
