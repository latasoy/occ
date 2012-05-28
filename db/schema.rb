# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 201204091000000) do

  create_table "bugs", :force => true do |t|
    t.string   "key"
    t.datetime "deleted_at"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "environments", :force => true do |t|
    t.string   "name"
    t.datetime "deleted_at"
    t.string   "run_options"
    t.datetime "started_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "first_started"
    t.datetime "last_finished"
    t.text     "sum_row"
    t.string   "agents"
    t.integer  "rerun"
    t.string   "file"
  end

  add_index "environments", ["name"], :name => "index_environments_on_name", :unique => true

  create_table "environments_lists", :id => false, :force => true do |t|
    t.integer "environment_id"
    t.integer "list_id"
  end

  create_table "erequests", :force => true do |t|
    t.integer  "environment_id"
    t.string   "command"
    t.datetime "finished_at"
    t.string   "message"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "user_id"
    t.string   "repo_version"
  end

  create_table "jobs", :force => true do |t|
    t.integer  "erequest_id"
    t.string   "environment_name",                                            :null => false
    t.integer  "machine_id"
    t.string   "list_name",                                                   :null => false
    t.integer  "list_id"
    t.text     "runid"
    t.integer  "stop_erequest_id"
    t.string   "run_options"
    t.boolean  "is_results_final",                         :default => false
    t.datetime "started_at"
    t.datetime "finished_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "tests_json",         :limit => 2147483647
    t.integer  "start_time"
    t.integer  "end_time"
    t.integer  "total",              :limit => 2
    t.integer  "fail",               :limit => 2
    t.integer  "pass",               :limit => 2
    t.integer  "skip",               :limit => 1
    t.integer  "results_start_time"
    t.integer  "results_end_time"
    t.integer  "stop_oats"
    t.string   "results_error"
    t.string   "results_status"
    t.string   "build_version_json"
    t.string   "browser"
    t.string   "logfile"
    t.string   "repo_version"
  end

  create_table "jobtests", :force => true do |t|
    t.integer  "job_id"
    t.string   "testid"
    t.integer  "bug_id"
    t.datetime "deleted_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "passed"
  end

  create_table "lists", :force => true do |t|
    t.string   "name"
    t.integer  "machine_id"
    t.datetime "deleted_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "rerun"
  end

  add_index "lists", ["name"], :name => "index_lists_on_name", :unique => true

  create_table "machines", :force => true do |t|
    t.string   "nickname"
    t.string   "name"
    t.integer  "port"
    t.string   "persisted_status"
    t.datetime "deleted_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "environments"
    t.string   "logfile"
    t.string   "password"
    t.string   "repo_version"
    t.integer  "job_id"
  end

  add_index "machines", ["nickname"], :name => "index_machines_on_nickname", :unique => true

  create_table "services", :force => true do |t|
    t.integer  "user_id"
    t.string   "provider"
    t.string   "uid"
    t.string   "name"
    t.string   "email"
    t.string   "first_name"
    t.string   "last_name"
    t.string   "nickname"
    t.string   "image"
    t.string   "url"
    t.string   "gender"
    t.string   "locale"
    t.string   "phone"
    t.string   "location"
    t.string   "description"
    t.string   "app_server"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "system_configs", :force => true do |t|
    t.string   "name"
    t.string   "value"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "description"
  end

  create_table "users", :force => true do |t|
    t.integer  "level"
    t.string   "uname"
    t.string   "password"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

end
