class AddEmbeddingsToKnowledgeDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :knowledge_documents, :embedding, :jsonb, null: false, default: []
    add_column :knowledge_documents, :embedding_model, :string
    add_column :knowledge_documents, :embedded_at, :datetime
  end
end
