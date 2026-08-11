class TeamLeadAssignment
  def self.assign(team:, user:)
    team.update!(team_lead: user)
    user.employment_detail.update!(team_id: team.id)
  end

  def self.unassign(team:)
    previous_lead = team.team_lead
    team.update!(team_lead_id: nil)
    previous_lead&.employment_detail&.update!(team_id: nil)
  end
end
