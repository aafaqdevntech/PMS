class AddLengthConstraintsToProjectsAndIssues < ActiveRecord::Migration[8.1]
  # Same 255/5000 rules the tasks table is created with. description and
  # resolution_note stay nullable here, so their constraints allow NULL.
  def up
    change_column :projects, :title, :string, limit: 255, null: false
    change_column :projects, :description, :text, limit: 5000
    change_column :issues, :title, :string, limit: 255, null: false
    change_column :issues, :description, :text, limit: 5000
    change_column :issues, :resolution_note, :text, limit: 5000

    add_check_constraint :projects, "length(title) BETWEEN 1 AND 255", name: "projects_title_length"
    add_check_constraint :projects, "description IS NULL OR length(description) <= 5000", name: "projects_description_length"
    add_check_constraint :issues, "length(title) BETWEEN 1 AND 255", name: "issues_title_length"
    add_check_constraint :issues, "description IS NULL OR length(description) <= 5000", name: "issues_description_length"
    add_check_constraint :issues, "resolution_note IS NULL OR length(resolution_note) <= 5000", name: "issues_resolution_note_length"
  end

  def down
    remove_check_constraint :issues, name: "issues_resolution_note_length"
    remove_check_constraint :issues, name: "issues_description_length"
    remove_check_constraint :issues, name: "issues_title_length"
    remove_check_constraint :projects, name: "projects_description_length"
    remove_check_constraint :projects, name: "projects_title_length"

    change_column :issues, :resolution_note, :text
    change_column :issues, :description, :text
    change_column :issues, :title, :string, null: false
    change_column :projects, :description, :text
    change_column :projects, :title, :string, null: false
  end
end
