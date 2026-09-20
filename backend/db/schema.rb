# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_20_000500) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "auth_sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "ip_address"
    t.datetime "last_used_at"
    t.bigint "platform_administrator_id"
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id"
    t.index ["expires_at"], name: "index_auth_sessions_on_expires_at"
    t.index ["platform_administrator_id"], name: "index_auth_sessions_on_platform_administrator_id"
    t.index ["token_digest"], name: "index_auth_sessions_on_token_digest", unique: true
    t.index ["user_id"], name: "index_auth_sessions_on_user_id"
    t.check_constraint "user_id IS NOT NULL AND platform_administrator_id IS NULL OR user_id IS NULL AND platform_administrator_id IS NOT NULL", name: "auth_sessions_exactly_one_actor"
  end

  create_table "business_policies", force: :cascade do |t|
    t.text "additional_information"
    t.bigint "business_id", null: false
    t.text "cash_on_delivery"
    t.datetime "created_at", null: false
    t.text "delivery_areas"
    t.text "delivery_charges"
    t.text "delivery_time"
    t.text "payment_methods"
    t.text "return_policy"
    t.datetime "updated_at", null: false
    t.index ["business_id"], name: "index_business_policies_on_business_id", unique: true
  end

  create_table "businesses", force: :cascade do |t|
    t.string "category"
    t.datetime "created_at", null: false
    t.string "currency", default: "BDT", null: false
    t.string "default_language", default: "banglish", null: false
    t.string "name", null: false
    t.jsonb "settings", default: {}, null: false
    t.string "slug", null: false
    t.string "status", default: "active", null: false
    t.string "timezone", default: "Asia/Dhaka", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_businesses_on_slug", unique: true
  end

  create_table "channel_connections", force: :cascade do |t|
    t.text "access_token"
    t.bigint "business_id", null: false
    t.string "channel", null: false
    t.datetime "created_at", null: false
    t.string "display_name"
    t.string "external_account_id", null: false
    t.jsonb "settings", default: {}, null: false
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.string "verify_token"
    t.index ["business_id"], name: "index_channel_connections_on_business_id"
    t.index ["channel", "external_account_id"], name: "index_channel_connections_on_channel_and_external_account_id", unique: true
  end

  create_table "conversations", force: :cascade do |t|
    t.bigint "business_id", null: false
    t.string "channel", null: false
    t.jsonb "conversation_state", default: {}, null: false
    t.datetime "created_at", null: false
    t.string "external_customer_id", null: false
    t.datetime "last_message_at"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["business_id", "channel", "external_customer_id"], name: "index_conversations_on_business_channel_customer", unique: true
    t.index ["business_id"], name: "index_conversations_on_business_id"
    t.index ["status"], name: "index_conversations_on_status"
  end

  create_table "delivery_integrations", force: :cascade do |t|
    t.boolean "active", default: false, null: false
    t.text "api_key"
    t.bigint "business_id", null: false
    t.datetime "created_at", null: false
    t.string "endpoint_url"
    t.string "provider", default: "manual", null: false
    t.jsonb "settings", default: {}, null: false
    t.datetime "updated_at", null: false
    t.index ["business_id"], name: "index_delivery_integrations_on_business_id", unique: true
  end

  create_table "delivery_submissions", force: :cascade do |t|
    t.integer "attempts", default: 0, null: false
    t.datetime "created_at", null: false
    t.bigint "delivery_integration_id", null: false
    t.string "external_reference"
    t.text "last_error"
    t.bigint "order_id", null: false
    t.integer "response_code"
    t.string "status", default: "pending", null: false
    t.datetime "submitted_at"
    t.datetime "updated_at", null: false
    t.index ["delivery_integration_id"], name: "index_delivery_submissions_on_delivery_integration_id"
    t.index ["order_id", "delivery_integration_id"], name: "index_delivery_submissions_unique", unique: true
    t.index ["order_id"], name: "index_delivery_submissions_on_order_id"
  end

  create_table "messages", force: :cascade do |t|
    t.text "content", null: false
    t.bigint "conversation_id", null: false
    t.datetime "created_at", null: false
    t.jsonb "metadata", default: {}, null: false
    t.integer "sender_type", null: false
    t.datetime "updated_at", null: false
    t.index ["conversation_id"], name: "index_messages_on_conversation_id"
    t.index ["sender_type"], name: "index_messages_on_sender_type"
  end

  create_table "messenger_deliveries", force: :cascade do |t|
    t.integer "attempts", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "delivered_at"
    t.text "last_error"
    t.bigint "message_id", null: false
    t.bigint "messenger_webhook_event_id", null: false
    t.string "recipient_id", null: false
    t.integer "response_code"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["message_id"], name: "index_messenger_deliveries_on_message_id", unique: true
    t.index ["messenger_webhook_event_id"], name: "index_messenger_deliveries_on_messenger_webhook_event_id"
    t.index ["status"], name: "index_messenger_deliveries_on_status"
  end

  create_table "messenger_webhook_events", force: :cascade do |t|
    t.bigint "business_id", null: false
    t.datetime "created_at", null: false
    t.string "event_type", null: false
    t.string "external_event_id"
    t.text "last_error"
    t.jsonb "payload", default: {}, null: false
    t.datetime "processed_at"
    t.string "sender_id"
    t.string "status", default: "received", null: false
    t.datetime "updated_at", null: false
    t.index ["business_id"], name: "index_messenger_webhook_events_on_business_id"
    t.index ["external_event_id"], name: "index_messenger_webhook_events_on_external_event_id", unique: true, where: "(external_event_id IS NOT NULL)"
    t.index ["sender_id"], name: "index_messenger_webhook_events_on_sender_id"
    t.index ["status"], name: "index_messenger_webhook_events_on_status"
  end

  create_table "order_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "order_id", null: false
    t.bigint "product_id"
    t.string "product_name", null: false
    t.bigint "product_variant_id"
    t.integer "quantity", null: false
    t.decimal "total", precision: 12, scale: 2, null: false
    t.decimal "unit_price", precision: 12, scale: 2, null: false
    t.datetime "updated_at", null: false
    t.string "variant_name"
    t.index ["order_id"], name: "index_order_items_on_order_id"
    t.index ["product_id"], name: "index_order_items_on_product_id"
    t.index ["product_variant_id"], name: "index_order_items_on_product_variant_id"
  end

  create_table "orders", force: :cascade do |t|
    t.text "address", null: false
    t.bigint "business_id", null: false
    t.datetime "confirmed_at", null: false
    t.bigint "conversation_id", null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "BDT", null: false
    t.string "customer_name", null: false
    t.decimal "delivery_charge", precision: 12, scale: 2, default: "0.0", null: false
    t.string "number", null: false
    t.bigint "pending_order_id", null: false
    t.string "phone", null: false
    t.string "status", default: "confirmed", null: false
    t.datetime "submitted_at"
    t.decimal "subtotal", precision: 12, scale: 2, null: false
    t.decimal "total", precision: 12, scale: 2, null: false
    t.datetime "updated_at", null: false
    t.index ["business_id", "confirmed_at"], name: "index_orders_on_business_id_and_confirmed_at"
    t.index ["business_id", "number"], name: "index_orders_on_business_id_and_number", unique: true
    t.index ["business_id", "status"], name: "index_orders_on_business_id_and_status"
    t.index ["business_id"], name: "index_orders_on_business_id"
    t.index ["conversation_id"], name: "index_orders_on_conversation_id"
    t.index ["pending_order_id"], name: "index_orders_on_pending_order_id", unique: true
  end

  create_table "pending_orders", force: :cascade do |t|
    t.text "address"
    t.jsonb "change_history", default: [], null: false
    t.bigint "conversation_id", null: false
    t.datetime "created_at", null: false
    t.string "customer_name"
    t.string "phone"
    t.bigint "product_id"
    t.bigint "product_variant_id"
    t.integer "quantity"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.string "woo_commerce_order_id"
    t.index ["conversation_id"], name: "index_pending_orders_on_conversation_id"
    t.index ["product_id"], name: "index_pending_orders_on_product_id"
    t.index ["product_variant_id"], name: "index_pending_orders_on_product_variant_id"
    t.index ["status"], name: "index_pending_orders_on_status"
    t.index ["woo_commerce_order_id"], name: "index_pending_orders_on_woo_commerce_order_id"
  end

  create_table "platform_administrators", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.datetime "last_seen_at"
    t.string "name", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_platform_administrators_on_email", unique: true
  end

  create_table "product_variants", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.decimal "price", precision: 10, scale: 2, null: false
    t.bigint "product_id", null: false
    t.string "size"
    t.string "sku"
    t.integer "stock_quantity", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["product_id", "sku"], name: "index_product_variants_on_product_id_and_sku", unique: true, where: "(sku IS NOT NULL)"
    t.index ["product_id"], name: "index_product_variants_on_product_id"
  end

  create_table "products", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.text "benefits"
    t.bigint "business_id", null: false
    t.string "category"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.decimal "price", precision: 10, scale: 2, null: false
    t.jsonb "product_attributes", default: {}, null: false
    t.text "short_description"
    t.integer "stock_quantity", default: 0, null: false
    t.text "suitable_for"
    t.string "tags"
    t.datetime "updated_at", null: false
    t.text "usage_instructions"
    t.string "woo_commerce_product_id"
    t.index ["active"], name: "index_products_on_active"
    t.index ["business_id"], name: "index_products_on_business_id"
    t.index ["woo_commerce_product_id"], name: "index_products_on_woo_commerce_product_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "api_token_digest", null: false
    t.bigint "business_id", null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.datetime "last_seen_at"
    t.string "name", null: false
    t.string "password_digest"
    t.string "role", default: "owner", null: false
    t.datetime "updated_at", null: false
    t.index ["api_token_digest"], name: "index_users_on_api_token_digest", unique: true
    t.index ["business_id"], name: "index_users_on_business_id"
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "auth_sessions", "platform_administrators"
  add_foreign_key "auth_sessions", "users"
  add_foreign_key "business_policies", "businesses"
  add_foreign_key "channel_connections", "businesses"
  add_foreign_key "conversations", "businesses"
  add_foreign_key "delivery_integrations", "businesses"
  add_foreign_key "delivery_submissions", "delivery_integrations"
  add_foreign_key "delivery_submissions", "orders"
  add_foreign_key "messages", "conversations"
  add_foreign_key "messenger_deliveries", "messages"
  add_foreign_key "messenger_deliveries", "messenger_webhook_events"
  add_foreign_key "messenger_webhook_events", "businesses"
  add_foreign_key "order_items", "orders"
  add_foreign_key "order_items", "product_variants"
  add_foreign_key "order_items", "products"
  add_foreign_key "orders", "businesses"
  add_foreign_key "orders", "conversations"
  add_foreign_key "orders", "pending_orders"
  add_foreign_key "pending_orders", "conversations"
  add_foreign_key "pending_orders", "product_variants"
  add_foreign_key "pending_orders", "products"
  add_foreign_key "product_variants", "products"
  add_foreign_key "products", "businesses"
  add_foreign_key "users", "businesses"
end
