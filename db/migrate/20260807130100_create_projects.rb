class CreateProjects < ActiveRecord::Migration[8.1]
  def change
    create_table :projects do |t|
      t.references :team, null: true, foreign_key: true, index: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }, index: true
      t.string :title, null: false
      t.text :description
      t.integer :status, null: false, default: 0
      t.date :start_date
      t.date :end_date

      t.timestamps
    end

    add_index :projects, :status
  end
end
