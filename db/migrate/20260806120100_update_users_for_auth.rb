class UpdateUsersForAuth < ActiveRecord::Migration[8.1]
  def up
    # Remove the bio and role columns from the users table, as they are no longer needed for authentication.
    remove_column :users, :bio, :string, if_exists: true
    remove_column :users, :role, :integer, if_exists: true

    add_column :users, :email, :string, unique: true, null: false
    add_column :users, :reset_password_token, :string
    add_column :users, :reset_password_sent_at, :datetime

    # Backfill any pre-existing rows (this app has no data yet in real
    # environments) with a unique placeholder before enforcing NOT NULL/UNIQUE.
    execute <<~SQL
      UPDATE users SET email = 'user' || id || '@example.com' WHERE email IS NULL
    SQL

    change_column_null :users, :email, false

    add_index :users, :username, unique: true unless index_exists?(:users, :username)
    add_index :users, :email, unique: true
    add_index :users, :reset_password_token, unique: true
  end

  def down
    remove_index :users, :reset_password_token
    remove_index :users, :email
    remove_column :users, :reset_password_sent_at
    remove_column :users, :reset_password_token
    remove_column :users, :email

    add_column :users, :role, :integer, null: false, default: 2
    add_column :users, :bio, :string
  end
end
