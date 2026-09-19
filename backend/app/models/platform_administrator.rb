class PlatformAdministrator < ApplicationRecord
  include PasswordAuthenticatable

  has_many :auth_sessions, dependent: :destroy

  normalizes :email, with: ->(email) { email.strip.downcase }
  validates :name, :email, :password_digest, presence: true
  validates :email, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
end
