require "digest"

class User < ApplicationRecord
  include PasswordAuthenticatable
  ROLES = %w[owner admin sales_agent fulfilment_agent analyst].freeze

  belongs_to :business
  has_many :auth_sessions, dependent: :destroy

  validates :name, :email, :api_token_digest, presence: true
  validates :email, uniqueness: true
  validates :role, inclusion: { in: ROLES }
  normalizes :email, with: ->(email) { email.strip.downcase }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }

  def self.issue_token
    token = SecureRandom.urlsafe_base64(32)
    [ token, Digest::SHA256.hexdigest(token) ]
  end

  def self.authenticate_token(token)
    return if token.blank?

    find_by(api_token_digest: Digest::SHA256.hexdigest(token))&.then { |user| user if user.active? }
  end
end
