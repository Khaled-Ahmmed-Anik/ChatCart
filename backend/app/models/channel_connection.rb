class ChannelConnection < ApplicationRecord
  CHANNELS = %w[facebook instagram whatsapp].freeze
  STATUSES = %w[active disconnected error].freeze

  belongs_to :business

  encrypts :access_token
  encrypts :verify_token

  validates :channel, inclusion: { in: CHANNELS }
  validates :status, inclusion: { in: STATUSES }
  validates :external_account_id, presence: true, uniqueness: { scope: :channel }

  scope :active, -> { where(status: "active") }
end
