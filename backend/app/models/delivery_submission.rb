class DeliverySubmission < ApplicationRecord
  STATUSES = %w[pending submitting submitted retrying failed].freeze

  belongs_to :order
  belongs_to :delivery_integration

  validates :status, inclusion: { in: STATUSES }
  validates :attempts, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
