class CreateMessengerDeliveries < ActiveRecord::Migration[8.1]
  def change
    create_table :messenger_deliveries do |t|
      t.references :messenger_webhook_event, null: false, foreign_key: true
      t.references :message, null: false, foreign_key: true, index: false
      t.string :recipient_id, null: false
      t.string :status, null: false, default: "pending"
      t.integer :attempts, null: false, default: 0
      t.integer :response_code
      t.text :last_error
      t.datetime :delivered_at

      t.timestamps
    end

    add_index :messenger_deliveries, :status
    add_index :messenger_deliveries, :message_id, unique: true
  end
end
