class IssueSerializer < ActiveModel::Serializer
  attributes :id, :project_id, :raised_by_id, :title, :description, :status,
             :resolution_note, :created_at, :updated_at
end
