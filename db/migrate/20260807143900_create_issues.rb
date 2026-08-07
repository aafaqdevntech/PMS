class CreateIssues < ActiveRecord::Migration[8.1]
  def change
    create_table :issues do |t|
      t.references :project, null: false, foreign_key: true, index: true
      t.references :raised_by, null: false, foreign_key: { to_table: :users }, index: true
      t.string :title, null: false
      t.text :description
      t.integer :status, null: false, default: 0
      t.text :resolution_note

      t.timestamps
    end

    add_index :issues, :status
  end
end
