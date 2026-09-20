class ProductImportDraft < ApplicationRecord
  STATUSES = %w[pending_review approved rejected failed].freeze

  belongs_to :business
  belongs_to :product, optional: true

  validates :source_url, presence: true
  validates :status, inclusion: { in: STATUSES }
end
