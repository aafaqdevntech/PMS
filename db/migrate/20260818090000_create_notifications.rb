class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications do |t|
      t.references :recipient, null: false, foreign_key: { to_table: :users }, index: true
      t.references :actor, null: false, foreign_key: { to_table: :users }, index: true
      t.references :issue, null: false, foreign_key: true, index: true
      t.integer :event_type, null: false
      t.datetime :read_at

      t.timestamps
    end

    add_index :notifications, [:recipient_id, :read_at]
    add_index :notifications, [:recipient_id, :created_at]

    add_check_constraint :notifications, "event_type BETWEEN 0 AND 2", name: "notifications_event_type_range"
  end
end
