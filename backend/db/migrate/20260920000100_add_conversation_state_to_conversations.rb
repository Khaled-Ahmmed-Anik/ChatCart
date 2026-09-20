class AddConversationStateToConversations < ActiveRecord::Migration[8.1]
  def change
    add_column :conversations, :conversation_state, :jsonb, null: false, default: {}
  end
end
