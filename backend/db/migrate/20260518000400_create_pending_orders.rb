class CreatePendingOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :pending_orders do |t|
      t.references :conversation, null: false, foreign_key: true
      t.references :product, foreign_key: true
      t.integer :quantity
      t.string :customer_name
      t.string :phone
      t.text :address
      t.integer :status, null: false, default: 0
      t.string :woo_commerce_order_id

      t.timestamps
    end

    add_index :pending_orders, :status
    add_index :pending_orders, :woo_commerce_order_id
  end
end
