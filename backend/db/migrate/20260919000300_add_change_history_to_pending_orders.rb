class AddChangeHistoryToPendingOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :pending_orders, :change_history, :jsonb, null: false, default: []
  end
end
