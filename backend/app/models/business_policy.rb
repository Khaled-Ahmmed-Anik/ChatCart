class BusinessPolicy < ApplicationRecord
  belongs_to :business

  after_commit :refresh_business_knowledge

  private

  def refresh_business_knowledge
    SyncBusinessKnowledgeJob.perform_later(business_id)
  end
end
