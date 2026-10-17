class AddCaptionEventToMessengerWebhookEvents < ActiveRecord::Migration[8.1]
  def change
    add_reference :messenger_webhook_events, :caption_event, index: { unique: true },
      foreign_key: { to_table: :messenger_webhook_events }
  end
end
