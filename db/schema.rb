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

ActiveRecord::Schema[8.1].define(version: 2026_03_03_034214) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "action_scripts", force: :cascade do |t|
    t.integer "action_type"
    t.boolean "active", default: true, null: false
    t.bigint "bill_id"
    t.text "context"
    t.datetime "created_at", null: false
    t.boolean "featured", default: false, null: false
    t.bigint "representative_id"
    t.text "script_template"
    t.integer "sort_order", default: 0
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["bill_id"], name: "index_action_scripts_on_bill_id"
    t.index ["representative_id"], name: "index_action_scripts_on_representative_id"
  end

  create_table "bills", force: :cascade do |t|
    t.string "bill_number"
    t.string "chamber"
    t.string "congress_bill_id"
    t.datetime "created_at", null: false
    t.string "data_source"
    t.text "editorial_summary"
    t.boolean "featured", default: false, null: false
    t.string "full_text_url"
    t.date "introduced_on"
    t.date "last_action_on"
    t.integer "level"
    t.string "openstates_bill_id"
    t.string "session_name"
    t.integer "session_year"
    t.string "slug"
    t.string "status"
    t.text "summary"
    t.string "title"
    t.datetime "updated_at", null: false
    t.string "utah_bill_id"
    t.index ["congress_bill_id"], name: "index_bills_on_congress_bill_id", unique: true, where: "(congress_bill_id IS NOT NULL)"
    t.index ["featured"], name: "index_bills_on_featured"
    t.index ["level"], name: "index_bills_on_level"
    t.index ["session_year"], name: "index_bills_on_session_year"
    t.index ["slug"], name: "index_bills_on_slug", unique: true
    t.index ["status"], name: "index_bills_on_status"
    t.index ["utah_bill_id"], name: "index_bills_on_utah_bill_id", unique: true, where: "(utah_bill_id IS NOT NULL)"
  end

  create_table "featured_items", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.bigint "featurable_id", null: false
    t.string "featurable_type", null: false
    t.string "headline"
    t.integer "section"
    t.integer "sort_order", default: 0
    t.datetime "updated_at", null: false
    t.index ["featurable_type", "featurable_id"], name: "index_featured_items_on_featurable"
  end

  create_table "issue_bills", force: :cascade do |t|
    t.bigint "bill_id", null: false
    t.datetime "created_at", null: false
    t.bigint "issue_id", null: false
    t.integer "popular_position", default: 0, null: false
    t.integer "sort_order", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["bill_id"], name: "index_issue_bills_on_bill_id"
    t.index ["issue_id", "bill_id"], name: "index_issue_bills_on_issue_id_and_bill_id", unique: true
    t.index ["issue_id"], name: "index_issue_bills_on_issue_id"
  end

  create_table "issues", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "against_label"
    t.datetime "created_at", null: false
    t.text "description"
    t.boolean "hot", default: false, null: false
    t.string "icon"
    t.string "name", null: false
    t.string "slug"
    t.integer "sort_order", default: 0, null: false
    t.string "stance_label"
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_issues_on_active"
    t.index ["slug"], name: "index_issues_on_slug", unique: true
    t.index ["sort_order"], name: "index_issues_on_sort_order"
  end

  create_table "representatives", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "bioguide_id"
    t.string "chamber"
    t.datetime "created_at", null: false
    t.string "district"
    t.string "email"
    t.string "facebook_url"
    t.string "first_name"
    t.string "full_name"
    t.string "last_name"
    t.integer "level"
    t.text "office_address"
    t.string "openstates_id"
    t.string "party"
    t.string "phone"
    t.string "phone_home"
    t.string "phone_mobile"
    t.string "phone_work"
    t.string "photo_url"
    t.integer "position_type"
    t.string "slug"
    t.string "title"
    t.string "twitter_handle"
    t.datetime "updated_at", null: false
    t.string "utah_leg_id"
    t.string "website_url"
    t.index ["active"], name: "index_representatives_on_active"
    t.index ["bioguide_id"], name: "index_representatives_on_bioguide_id", unique: true, where: "(bioguide_id IS NOT NULL)"
    t.index ["level"], name: "index_representatives_on_level"
    t.index ["openstates_id"], name: "index_representatives_on_openstates_id", unique: true, where: "(openstates_id IS NOT NULL)"
    t.index ["party"], name: "index_representatives_on_party"
    t.index ["position_type"], name: "index_representatives_on_position_type"
    t.index ["slug"], name: "index_representatives_on_slug", unique: true
    t.index ["utah_leg_id"], name: "index_representatives_on_utah_leg_id", unique: true, where: "(utah_leg_id IS NOT NULL)"
  end

  create_table "votes", force: :cascade do |t|
    t.bigint "bill_id", null: false
    t.datetime "created_at", null: false
    t.string "data_source"
    t.integer "position"
    t.bigint "representative_id", null: false
    t.datetime "updated_at", null: false
    t.date "voted_on"
    t.index ["bill_id"], name: "index_votes_on_bill_id"
    t.index ["representative_id", "bill_id"], name: "index_votes_on_representative_id_and_bill_id", unique: true
    t.index ["representative_id"], name: "index_votes_on_representative_id"
  end

  add_foreign_key "action_scripts", "bills"
  add_foreign_key "action_scripts", "representatives"
  add_foreign_key "issue_bills", "bills"
  add_foreign_key "issue_bills", "issues"
  add_foreign_key "votes", "bills"
  add_foreign_key "votes", "representatives"
end
