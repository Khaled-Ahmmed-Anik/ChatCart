class SyncBusinessKnowledgeJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  def perform(business_id)
    BusinessKnowledgeIndexer.new(business: Business.find(business_id)).sync!
  end
end
