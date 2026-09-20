class CreateMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :messages do |t|
      t.references :conversation, null: false, foreign_key: true
      t.integer :sender_type, null: false
      t.text :content, null: false
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :messages, :sender_type
  end
end
