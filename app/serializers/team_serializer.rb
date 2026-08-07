class TeamSerializer < ActiveModel::Serializer
  attributes :id, :name, :description, :team_lead_id, :created_at, :updated_at
end
