class CreatePendingOrderItems < ActiveRecord::Migration[8.1]
  def change
    create_table :pending_order_items do |t|
      t.references :pending_order, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.references :product_variant, foreign_key: true
      t.integer :quantity, null: false
      t.timestamps
    end
  end
end
