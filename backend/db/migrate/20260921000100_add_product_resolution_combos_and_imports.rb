class AddProductResolutionCombosAndImports < ActiveRecord::Migration[8.1]
  def change
    change_table :products, bulk: true do |t|
      t.string :product_type, null: false, default: "standard"
      t.string :stock_strategy, null: false, default: "independent"
      t.text :aliases, array: true, null: false, default: []
      t.text :image_urls, array: true, null: false, default: []
      t.string :source_url
      t.datetime :imported_at
      t.string :import_status
      t.text :import_error
      t.datetime :archived_at
    end

    create_table :combo_items do |t|
      t.references :combo_product, null: false, foreign_key: { to_table: :products }
      t.references :component_product, null: false, foreign_key: { to_table: :products }
      t.integer :quantity, null: false, default: 1
      t.string :selection_group
      t.boolean :required, null: false, default: true
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :combo_items, [ :combo_product_id, :component_product_id, :selection_group ],
      unique: true, name: "index_combo_items_on_product_component_group"

    create_table :product_import_drafts do |t|
      t.references :business, null: false, foreign_key: true
      t.string :source_url, null: false
      t.string :status, null: false, default: "pending_review"
      t.jsonb :extracted_data, null: false, default: {}
      t.text :error
      t.references :product, foreign_key: true
      t.timestamps
    end
    add_index :product_import_drafts, [ :business_id, :source_url, :status ],
      name: "index_product_import_drafts_for_review"

    add_column :order_items, :combo_components, :jsonb, null: false, default: []
  end
end
