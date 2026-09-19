class Business < ApplicationRecord
  STATUSES = %w[active suspended].freeze

  has_many :users, dependent: :destroy
  has_many :products, dependent: :destroy
  has_many :conversations, dependent: :destroy
  has_many :orders, dependent: :destroy
  has_many :channel_connections, dependent: :destroy
  has_many :messenger_webhook_events, dependent: :destroy
  has_one :business_policy, dependent: :destroy
  has_one :delivery_integration, dependent: :destroy

  validates :name, :slug, :default_language, :timezone, :currency, presence: true
  validates :slug, uniqueness: true, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }
  validates :status, inclusion: { in: STATUSES }

  def self.default
    find_by(slug: "chatcart") || first || create!(name: "ChatCart", slug: "chatcart", category: "retail")
  end

  def policy
    business_policy || build_business_policy
  end
end
