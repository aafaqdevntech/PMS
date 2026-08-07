class AddUniqueIndexToTeamsTeamLeadId < ActiveRecord::Migration[8.1]
  def change
    remove_index :teams, :team_lead_id
    add_index :teams, :team_lead_id, unique: true
  end
end
