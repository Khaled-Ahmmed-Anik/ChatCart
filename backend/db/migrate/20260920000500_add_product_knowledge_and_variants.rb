class AddProductKnowledgeAndVariants < ActiveRecord::Migration[8.1]
  def change
    change_table :products, bulk: true do |t|
      t.string :category
      t.text :short_description
      t.text :benefits
      t.text :usage_instructions
      t.text :suitable_for
      t.jsonb :product_attributes, null: false, default: {}
    end

    create_table :product_variants do |t|
      t.references :product, null: false, foreign_key: true
      t.string :name, null: false
      t.string :size
      t.string :sku
      t.decimal :price, precision: 10, scale: 2, null: false
      t.integer :stock_quantity, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :product_variants, [ :product_id, :sku ], unique: true, where: "sku IS NOT NULL"

    add_reference :pending_orders, :product_variant, foreign_key: true
    add_reference :order_items, :product_variant, foreign_key: true
    add_column :order_items, :variant_name, :string
  end
end
