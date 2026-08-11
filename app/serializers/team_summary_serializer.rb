class TeamSummarySerializer < ActiveModel::Serializer
  attributes :id, :name, :team_lead_id, :team_lead_name, :description, :created_at

  def team_lead_name
    object.team_lead&.profile&.full_name
  end
end
