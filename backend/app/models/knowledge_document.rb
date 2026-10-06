class KnowledgeDocument < ApplicationRecord
  SOURCE_TYPES = %w[product business_policy manual].freeze

  belongs_to :business

  scope :active, -> { where(active: true) }

  validates :source_type, inclusion: { in: SOURCE_TYPES }
  validates :title, :content, :checksum, presence: true
  validates :source_id, uniqueness: { scope: [ :business_id, :source_type ], allow_nil: true }

  def self.checksum_for(title:, content:, metadata: {})
    Digest::SHA256.hexdigest([ title, content, metadata.deep_stringify_keys.sort.to_h.to_json ].join("\n"))
  end
end
