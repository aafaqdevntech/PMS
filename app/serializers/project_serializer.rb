class ProjectSerializer < ActiveModel::Serializer
  attributes :id, :team_id, :created_by_id, :title, :description, :status,
             :start_date, :end_date, :created_at, :updated_at
end
