module PasswordAuthenticatable
  extend ActiveSupport::Concern

  included do
    attr_reader :password
    validates :password, length: { minimum: 12 }, if: -> { password.present? }
  end

  def password=(value)
    @password = value
    self.password_digest = PasswordHasher.create(value) if value.present?
  end

  def authenticate(password_attempt)
    self if authentication_allowed? && PasswordHasher.matches?(password_digest, password_attempt)
  end

  def authentication_allowed?
    active?
  end
end
