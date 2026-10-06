namespace :knowledge do
  desc "Synchronize product and policy knowledge for every active business"
  task sync: :environment do
    Business.where(status: "active").find_each do |business|
      BusinessKnowledgeIndexer.new(business: business).sync!
      puts "Indexed #{business.slug}: #{business.knowledge_documents.active.count} active documents"
    end
  end
end
