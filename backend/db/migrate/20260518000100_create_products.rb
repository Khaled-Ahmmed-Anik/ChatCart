class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |t|
      t.string :name, null: false
      t.string :woo_commerce_product_id
      t.decimal :price, precision: 10, scale: 2, null: false
      t.integer :stock_quantity, null: false, default: 0
      t.text :description
      t.string :tags
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :products, :woo_commerce_product_id
    add_index :products, :active
  end
end
