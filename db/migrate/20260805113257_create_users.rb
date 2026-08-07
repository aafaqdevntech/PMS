class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :username, null: false
      t.string :password_digest, null: false
      t.string :bio
      t.integer :role, null: false, default: 2

      t.timestamps
    end
    # create_table :users do |t|
    #   t.string :username
    #   t.string :password_digest
    #   t.string :bio

    #   t.timestamps
    # end
  end
end
