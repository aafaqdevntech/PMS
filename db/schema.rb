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

ActiveRecord::Schema[8.1].define(version: 2026_08_07_143900) do
  create_table "employment_details", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "job_position"
    t.datetime "joined_at"
    t.integer "role", default: 2, null: false
    t.integer "team_id"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["team_id"], name: "index_employment_details_on_team_id"
    t.index ["user_id"], name: "index_employment_details_on_user_id", unique: true
  end

  create_table "issues", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "project_id", null: false
    t.integer "raised_by_id", null: false
    t.text "resolution_note"
    t.integer "status", default: 0, null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_issues_on_project_id"
    t.index ["raised_by_id"], name: "index_issues_on_raised_by_id"
    t.index ["status"], name: "index_issues_on_status"
  end

  create_table "profiles", force: :cascade do |t|
    t.string "address"
    t.string "city"
    t.string "country"
    t.datetime "created_at", null: false
    t.string "full_name", null: false
    t.string "image_url"
    t.string "phone"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_profiles_on_user_id", unique: true
  end

  create_table "projects", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "created_by_id", null: false
    t.text "description"
    t.date "end_date"
    t.date "start_date"
    t.integer "status", default: 0, null: false
    t.integer "team_id"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_projects_on_created_by_id"
    t.index ["status"], name: "index_projects_on_status"
    t.index ["team_id"], name: "index_projects_on_team_id"
  end

  create_table "teams", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.integer "team_lead_id"
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_teams_on_name", unique: true
    t.index ["team_lead_id"], name: "index_teams_on_team_lead_id", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.string "username", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "employment_details", "teams"
  add_foreign_key "employment_details", "users"
  add_foreign_key "issues", "projects"
  add_foreign_key "issues", "users", column: "raised_by_id"
  add_foreign_key "profiles", "users"
  add_foreign_key "projects", "teams"
  add_foreign_key "projects", "users", column: "created_by_id"
  add_foreign_key "teams", "users", column: "team_lead_id"
end
