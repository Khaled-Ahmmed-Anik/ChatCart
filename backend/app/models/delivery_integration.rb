class DeliveryIntegration < ApplicationRecord
  PROVIDERS = %w[manual webhook].freeze

  belongs_to :business
  has_many :delivery_submissions, dependent: :restrict_with_error

  encrypts :api_key

  validates :provider, inclusion: { in: PROVIDERS }
  validates :endpoint_url, presence: true, if: -> { active? && provider == "webhook" }
end
