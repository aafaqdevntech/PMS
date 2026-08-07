class RelaxEmploymentDetailTeamAndProfileName < ActiveRecord::Migration[8.1]
  def up
    # Admins have no team, and a newly-added employee may not be assigned to
    # one yet, so team_id can't be required.
    change_column_null :employment_details, :team_id, true

    # Matches the profiles migration's null: false on full_name.
    change_column_null :profiles, :full_name, false
  end

  def down
    change_column_null :profiles, :full_name, true
    change_column_null :employment_details, :team_id, false
  end
end
