class CreateTasks < ActiveRecord::Migration[8.1]
  def change
    create_table :tasks do |t|
      t.references :project, null: false, foreign_key: true, index: true
      # Optional: a task may be created from scratch, or promoted from an
      # issue raised against the same project.
      t.references :issue, null: true, foreign_key: true, index: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }, index: true
      t.references :assigned_to, null: true, foreign_key: { to_table: :users }, index: true
      t.string :title, null: false, limit: 255
      t.text :description, null: false, limit: 5000
      t.integer :priority, null: false, default: 3
      t.integer :status, null: false, default: 0
      t.date :due_date

      t.timestamps
    end

    add_index :tasks, :status
    add_index :tasks, :priority

    # SQLite ignores varchar(255)/text(5000), so the limits above are only
    # documentation — these constraints are what actually enforce them. They
    # are deliberately never stricter than the model validations, so input
    # that passes validation can never trip a constraint.
    add_check_constraint :tasks, "length(title) BETWEEN 1 AND 255", name: "tasks_title_length"
    add_check_constraint :tasks, "length(description) BETWEEN 1 AND 5000", name: "tasks_description_length"
    add_check_constraint :tasks, "priority BETWEEN 0 AND 3", name: "tasks_priority_range"
    add_check_constraint :tasks, "status BETWEEN 0 AND 6", name: "tasks_status_range"
    add_check_constraint :tasks, "due_date IS NULL OR date(due_date) IS NOT NULL", name: "tasks_due_date_is_date"
  end
end
