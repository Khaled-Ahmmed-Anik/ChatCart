class CreateWhatsappMessaging < ActiveRecord::Migration[8.1]
  def change
    create_table :whatsapp_webhook_events do |t|
      t.references :business, null: false, foreign_key: true
      t.string :event_type, null: false
      t.string :external_event_id
      t.string :sender_id
      t.string :phone_number_id
      t.jsonb :payload, null: false, default: {}
      t.string :status, null: false, default: "received"
      t.datetime :processed_at
      t.text :last_error
      t.timestamps
    end
    add_index :whatsapp_webhook_events, :external_event_id, unique: true,
      where: "external_event_id IS NOT NULL"
    add_index :whatsapp_webhook_events, [ :business_id, :sender_id, :status ],
      name: "index_whatsapp_events_for_processing"

    create_table :whatsapp_deliveries do |t|
      t.references :whatsapp_webhook_event, null: false, foreign_key: true
      t.references :message, null: false, foreign_key: true, index: { unique: true }
      t.string :recipient_id, null: false
      t.string :phone_number_id, null: false
      t.string :status, null: false, default: "pending"
      t.integer :attempts, null: false, default: 0
      t.integer :response_code
      t.jsonb :response_body, null: false, default: {}
      t.text :last_error
      t.string :external_message_id
      t.datetime :delivered_at
      t.timestamps
    end
    add_index :whatsapp_deliveries, :external_message_id, unique: true,
      where: "external_message_id IS NOT NULL"
  end
end
