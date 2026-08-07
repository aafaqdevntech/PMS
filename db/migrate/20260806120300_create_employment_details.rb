class CreateEmploymentDetails < ActiveRecord::Migration[8.1]
  def change
    create_table :employment_details do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true } # will have user_id.
      t.references :team, foreign_key: true # will have team_id.
      t.integer :role, null: false, default: 2
      t.string :job_position
      t.datetime :joined_at

      t.timestamps
    end
  end
end
