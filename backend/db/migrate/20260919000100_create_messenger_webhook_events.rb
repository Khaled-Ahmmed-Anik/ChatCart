class CreateMessengerWebhookEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :messenger_webhook_events do |t|
      t.string :event_type, null: false
      t.string :external_event_id
      t.string :sender_id
      t.jsonb :payload, null: false, default: {}
      t.string :status, null: false, default: "received"
      t.datetime :processed_at
      t.text :last_error

      t.timestamps
    end

    add_index :messenger_webhook_events, :external_event_id,
      unique: true,
      where: "external_event_id IS NOT NULL"
    add_index :messenger_webhook_events, :status
    add_index :messenger_webhook_events, :sender_id
  end
end
