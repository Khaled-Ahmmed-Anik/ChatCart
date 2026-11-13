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
  has_many :knowledge_documents, dependent: :destroy
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

  def automation_paused?
    settings.to_h[Constants::Automation::PAUSED] == true
  end

  def automation_paused=(paused)
    values = settings.to_h.merge(Constants::Automation::PAUSED => paused)
    if paused && !automation_paused?
      values[Constants::Automation::PAUSED_AT] = Time.current.iso8601(6)
    elsif !paused && automation_paused?
      values[Constants::Automation::RESUMED_AT] = Time.current.iso8601(6)
    end
    self.settings = values
  end

  def blocks_automated_reply?(message)
    return false unless message.bot?
    return true if automation_paused?

    paused_at = settings.to_h[Constants::Automation::PAUSED_AT]
    paused_at.present? && (message.created_at <= Time.iso8601(paused_at) ||
      message.metadata.to_h[Constants::Automation::EPOCH] != paused_at)
  end

  def suppresses_incoming_automation?(received_at)
    return true if automation_paused?

    resumed_at = settings.to_h[Constants::Automation::RESUMED_AT]
    resumed_at.present? && received_at < Time.iso8601(resumed_at)
  end

  private

  def revoke_user_sessions_when_deactivated
    return unless will_save_change_to_status? && !active?

    auth_sessions.active.revoke_all!(reason: AuthSession::BUSINESS_INACTIVE_REASON)
  end
end
