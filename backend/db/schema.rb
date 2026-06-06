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

ActiveRecord::Schema[8.1].define(version: 2026_05_18_000400) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "conversations", force: :cascade do |t|
    t.string "channel", null: false
    t.datetime "created_at", null: false
    t.string "external_customer_id", null: false
    t.datetime "last_message_at"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["channel", "external_customer_id"], name: "index_conversations_on_channel_and_external_customer_id", unique: true
    t.index ["status"], name: "index_conversations_on_status"
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

  create_table "pending_orders", force: :cascade do |t|
    t.text "address"
    t.bigint "conversation_id", null: false
    t.datetime "created_at", null: false
    t.string "customer_name"
    t.string "phone"
    t.bigint "product_id"
    t.integer "quantity"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.string "woo_commerce_order_id"
    t.index ["conversation_id"], name: "index_pending_orders_on_conversation_id"
    t.index ["product_id"], name: "index_pending_orders_on_product_id"
    t.index ["status"], name: "index_pending_orders_on_status"
    t.index ["woo_commerce_order_id"], name: "index_pending_orders_on_woo_commerce_order_id"
  end

  create_table "products", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.decimal "price", precision: 10, scale: 2, null: false
    t.integer "stock_quantity", default: 0, null: false
    t.string "tags"
    t.datetime "updated_at", null: false
    t.string "woo_commerce_product_id"
    t.index ["active"], name: "index_products_on_active"
    t.index ["woo_commerce_product_id"], name: "index_products_on_woo_commerce_product_id"
  end

  add_foreign_key "messages", "conversations"
  add_foreign_key "pending_orders", "conversations"
  add_foreign_key "pending_orders", "products"
end
