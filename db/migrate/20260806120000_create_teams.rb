class CreateTeams < ActiveRecord::Migration[8.1]
  def change
    create_table :teams do |t|
      t.string :name, null: false, unique: true
      t.text :description
      # team_lead_id is made nullable to allow for teams without a lead initially. It can be set later when a lead is assigned.
      t.references :team_lead, null: true, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :teams, :name, unique: true
  end
end
