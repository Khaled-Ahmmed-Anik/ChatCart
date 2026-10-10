namespace :knowledge do
  desc "Synchronize product and policy knowledge for every active business"
  task sync: :environment do
    Business.where(status: "active").find_each do |business|
      BusinessKnowledgeIndexer.new(business: business).sync!
      puts "Indexed #{business.slug}: #{business.knowledge_documents.active.count} active documents"
    end
  end


  desc "Queue embeddings for active knowledge documents that do not have one"
  task embed: :environment do
    KnowledgeDocument.active.where(embedding: []).find_each do |document|
      EmbedKnowledgeDocumentJob.perform_later(document.id)
    end
    puts "Queued missing knowledge embeddings"
  end
end
