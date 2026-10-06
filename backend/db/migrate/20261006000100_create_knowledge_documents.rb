class CreateKnowledgeDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :knowledge_documents do |t|
      t.references :business, null: false, foreign_key: true
      t.string :source_type, null: false
      t.bigint :source_id
      t.string :title, null: false
      t.text :content, null: false
      t.jsonb :metadata, null: false, default: {}
      t.string :checksum, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_index :knowledge_documents, [ :business_id, :source_type, :source_id ],
      unique: true, name: "index_knowledge_documents_on_tenant_source"
    add_index :knowledge_documents, :active
    add_index :knowledge_documents,
      "to_tsvector('simple', coalesce(title, '') || ' ' || coalesce(content, ''))",
      using: :gin, name: "index_knowledge_documents_on_search_text"
  end
end
