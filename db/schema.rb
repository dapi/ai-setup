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

ActiveRecord::Schema[7.1].define(version: 2026_04_11_100300) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "conversations", force: :cascade do |t|
    t.bigint "guest_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["guest_id"], name: "index_conversations_on_guest_id"
  end

  create_table "departments", force: :cascade do |t|
    t.bigint "hotel_id", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["hotel_id"], name: "index_departments_on_hotel_id"
  end

  create_table "guests", force: :cascade do |t|
    t.bigint "hotel_id", null: false
    t.string "room_number"
    t.string "name", null: false
    t.string "identifier_token", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["hotel_id"], name: "index_guests_on_hotel_id"
    t.index ["identifier_token"], name: "index_guests_on_identifier_token"
  end

  create_table "hotels", force: :cascade do |t|
    t.string "name", null: false
    t.string "timezone", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "slug", null: false
    t.index ["name"], name: "index_hotels_on_name", unique: true
    t.index ["slug"], name: "index_hotels_on_slug", unique: true
  end

  create_table "knowledge_base_articles", force: :cascade do |t|
    t.bigint "hotel_id", null: false
    t.string "title", null: false
    t.text "content", null: false
    t.string "category"
    t.boolean "published", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["hotel_id"], name: "index_knowledge_base_articles_on_hotel_id"
  end

  create_table "messages", force: :cascade do |t|
    t.bigint "conversation_id", null: false
    t.string "sender_type", null: false
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["conversation_id"], name: "index_messages_on_conversation_id"
  end

  create_table "staffs", force: :cascade do |t|
    t.bigint "hotel_id", null: false
    t.integer "role", default: 2, null: false
    t.string "name", null: false
    t.string "email", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "password_digest", null: false
    t.index ["hotel_id"], name: "index_staffs_on_hotel_id"
  end

  create_table "tickets", force: :cascade do |t|
    t.bigint "guest_id", null: false
    t.bigint "department_id", null: false
    t.bigint "staff_id"
    t.integer "status", default: 0, null: false
    t.integer "priority", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "hotel_id", null: false
    t.string "subject", default: "", null: false
    t.text "body", default: "", null: false
    t.index ["department_id"], name: "index_tickets_on_department_id"
    t.index ["guest_id"], name: "index_tickets_on_guest_id"
    t.index ["hotel_id"], name: "index_tickets_on_hotel_id"
    t.index ["staff_id"], name: "index_tickets_on_staff_id"
  end

  add_foreign_key "conversations", "guests"
  add_foreign_key "departments", "hotels"
  add_foreign_key "guests", "hotels"
  add_foreign_key "knowledge_base_articles", "hotels"
  add_foreign_key "messages", "conversations"
  add_foreign_key "staffs", "hotels"
  add_foreign_key "tickets", "departments"
  add_foreign_key "tickets", "guests"
  add_foreign_key "tickets", "hotels"
  add_foreign_key "tickets", "staffs"
end
