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

ActiveRecord::Schema[8.1].define(version: 2025_11_26_165648) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "answers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "option_id", null: false
    t.bigint "question_id", null: false
    t.bigint "session_id", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_answers_on_option_id"
    t.index ["question_id"], name: "index_answers_on_question_id"
    t.index ["session_id"], name: "index_answers_on_session_id"
  end

  create_table "dishes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "cuisine"
    t.text "description"
    t.string "genre"
    t.string "heaviness"
    t.string "name"
    t.string "recipe_url"
    t.datetime "updated_at", null: false
  end

  create_table "histories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "decided_at"
    t.bigint "dish_id", null: false
    t.bigint "session_id", null: false
    t.datetime "updated_at", null: false
    t.index ["dish_id"], name: "index_histories_on_dish_id"
    t.index ["session_id"], name: "index_histories_on_session_id"
  end

  create_table "options", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "dish_id"
    t.integer "next_question_id"
    t.bigint "question_id", null: false
    t.string "text"
    t.datetime "updated_at", null: false
    t.index ["question_id"], name: "index_options_on_question_id"
  end

  create_table "questions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "order_index"
    t.integer "routing"
    t.string "text"
    t.datetime "updated_at", null: false
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "dish_id"
    t.datetime "finished_at"
    t.json "messages", default: []
    t.datetime "started_at"
    t.jsonb "state", default: {}, null: false
    t.datetime "updated_at", null: false
    t.string "uuid", null: false
    t.index ["dish_id"], name: "index_sessions_on_dish_id"
    t.index ["uuid"], name: "index_sessions_on_uuid", unique: true
  end

  add_foreign_key "answers", "options"
  add_foreign_key "answers", "questions"
  add_foreign_key "answers", "sessions"
  add_foreign_key "histories", "dishes"
  add_foreign_key "histories", "sessions"
  add_foreign_key "options", "questions"
  add_foreign_key "sessions", "dishes"
end
