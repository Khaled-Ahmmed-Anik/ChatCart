class CreateCommercePlatformFoundation < ActiveRecord::Migration[8.1]
  def up
    create_table :businesses do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :category
      t.string :default_language, null: false, default: "banglish"
      t.string :timezone, null: false, default: "Asia/Dhaka"
      t.string :currency, null: false, default: "BDT"
      t.string :status, null: false, default: "active"
      t.jsonb :settings, null: false, default: {}
      t.timestamps
    end
    add_index :businesses, :slug, unique: true

    create_table :users do |t|
      t.references :business, null: false, foreign_key: true
      t.string :name, null: false
      t.string :email, null: false
      t.string :role, null: false, default: "owner"
      t.string :api_token_digest, null: false
      t.boolean :active, null: false, default: true
      t.datetime :last_seen_at
      t.timestamps
    end
    add_index :users, :email, unique: true
    add_index :users, :api_token_digest, unique: true

    create_table :business_policies do |t|
      t.references :business, null: false, foreign_key: true, index: { unique: true }
      t.text :payment_methods
      t.text :cash_on_delivery
      t.text :delivery_charges
      t.text :delivery_areas
      t.text :delivery_time
      t.text :return_policy
      t.text :additional_information
      t.timestamps
    end

    create_table :channel_connections do |t|
      t.references :business, null: false, foreign_key: true
      t.string :channel, null: false
      t.string :external_account_id, null: false
      t.string :display_name
      t.text :access_token
      t.string :verify_token
      t.string :status, null: false, default: "active"
      t.jsonb :settings, null: false, default: {}
      t.timestamps
    end
    add_index :channel_connections, [ :channel, :external_account_id ], unique: true

    add_reference :products, :business, foreign_key: true
    add_reference :conversations, :business, foreign_key: true
    add_reference :messenger_webhook_events, :business, foreign_key: true

    default_business_id = insert_default_business
    execute "UPDATE products SET business_id = #{default_business_id} WHERE business_id IS NULL"
    execute "UPDATE conversations SET business_id = #{default_business_id} WHERE business_id IS NULL"
    execute "UPDATE messenger_webhook_events SET business_id = #{default_business_id} WHERE business_id IS NULL"
    change_column_null :products, :business_id, false
    change_column_null :conversations, :business_id, false
    change_column_null :messenger_webhook_events, :business_id, false
    remove_index :conversations, name: :index_conversations_on_channel_and_external_customer_id
    add_index :conversations, [ :business_id, :channel, :external_customer_id ], unique: true,
      name: :index_conversations_on_business_channel_customer
    add_index :products, [ :business_id, :name ], unique: true

    create_table :orders do |t|
      t.references :business, null: false, foreign_key: true
      t.references :conversation, null: false, foreign_key: true
      t.references :pending_order, null: false, foreign_key: true, index: { unique: true }
      t.string :number, null: false
      t.string :status, null: false, default: "confirmed"
      t.string :customer_name, null: false
      t.string :phone, null: false
      t.text :address, null: false
      t.string :currency, null: false, default: "BDT"
      t.decimal :subtotal, precision: 12, scale: 2, null: false
      t.decimal :delivery_charge, precision: 12, scale: 2, null: false, default: 0
      t.decimal :total, precision: 12, scale: 2, null: false
      t.datetime :confirmed_at, null: false
      t.datetime :submitted_at
      t.timestamps
    end
    add_index :orders, [ :business_id, :number ], unique: true
    add_index :orders, [ :business_id, :status ]
    add_index :orders, [ :business_id, :confirmed_at ]

    create_table :order_items do |t|
      t.references :order, null: false, foreign_key: true
      t.references :product, null: true, foreign_key: true
      t.string :product_name, null: false
      t.integer :quantity, null: false
      t.decimal :unit_price, precision: 12, scale: 2, null: false
      t.decimal :total, precision: 12, scale: 2, null: false
      t.timestamps
    end

    create_table :delivery_integrations do |t|
      t.references :business, null: false, foreign_key: true, index: { unique: true }
      t.string :provider, null: false, default: "manual"
      t.string :endpoint_url
      t.text :api_key
      t.boolean :active, null: false, default: false
      t.jsonb :settings, null: false, default: {}
      t.timestamps
    end

    create_table :delivery_submissions do |t|
      t.references :order, null: false, foreign_key: true
      t.references :delivery_integration, null: false, foreign_key: true
      t.string :status, null: false, default: "pending"
      t.integer :attempts, null: false, default: 0
      t.string :external_reference
      t.integer :response_code
      t.text :last_error
      t.datetime :submitted_at
      t.timestamps
    end
    add_index :delivery_submissions, [ :order_id, :delivery_integration_id ], unique: true,
      name: :index_delivery_submissions_unique
  end

  def down
    drop_table :delivery_submissions
    drop_table :delivery_integrations
    drop_table :order_items
    drop_table :orders
    remove_index :products, column: [ :business_id, :name ]
    remove_index :conversations, name: :index_conversations_on_business_channel_customer
    add_index :conversations, [ :channel, :external_customer_id ], unique: true
    remove_reference :conversations, :business, foreign_key: true
    remove_reference :products, :business, foreign_key: true
    remove_reference :messenger_webhook_events, :business, foreign_key: true
    drop_table :channel_connections
    drop_table :business_policies
    drop_table :users
    drop_table :businesses
  end

  private

  def insert_default_business
    quoted_time = connection.quote(Time.current)
    result = execute(<<~SQL.squish)
      INSERT INTO businesses (name, slug, category, created_at, updated_at)
      VALUES ('ChatCart', 'chatcart', 'retail', #{quoted_time}, #{quoted_time})
      RETURNING id
    SQL
    result.first.fetch("id")
  end
end
