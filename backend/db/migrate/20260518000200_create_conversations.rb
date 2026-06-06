class CreateConversations < ActiveRecord::Migration[8.1]
  def change
    create_table :conversations do |t|
      t.string :external_customer_id, null: false
      t.string :channel, null: false
      t.integer :status, null: false, default: 0
      t.datetime :last_message_at

      t.timestamps
    end

    add_index :conversations, [:channel, :external_customer_id], unique: true
    add_index :conversations, :status
  end
end
