class Business < ApplicationRecord
  STATUSES = %w[active suspended disabled].freeze

  has_many :users, dependent: :destroy
  has_many :auth_sessions, through: :users
  has_many :products, dependent: :destroy
  has_many :product_import_drafts, dependent: :destroy
  has_many :conversations, dependent: :destroy
  has_many :orders, dependent: :destroy
  has_many :channel_connections, dependent: :destroy
  has_many :messenger_webhook_events, dependent: :destroy
  has_one :business_policy, dependent: :destroy
  has_one :delivery_integration, dependent: :destroy

  validates :name, :slug, :default_language, :timezone, :currency, presence: true
  validates :slug, uniqueness: true, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }
  validates :status, inclusion: { in: STATUSES }

  before_update :revoke_user_sessions_when_deactivated

  def self.default
    find_by(slug: "chatcart") || first || create!(name: "ChatCart", slug: "chatcart", category: "retail")
  end

  def policy
    business_policy || build_business_policy
  end

  def active?
    status == "active"
  end

  private

  def revoke_user_sessions_when_deactivated
    return unless will_save_change_to_status? && !active?

    auth_sessions.active.revoke_all!(reason: AuthSession::BUSINESS_INACTIVE_REASON)
  end
end
