class ChangeColumns < ActiveRecord::Migration
  def self.up
#    add_column :erequests, :repo_version, :string
    add_column :system_configs, :description, :text
#    rename_column :machines, :svn, :repo_version
#   remove_column :jobtests, :passed
  end
end
