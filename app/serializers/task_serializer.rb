class TaskSerializer < ActiveModel::Serializer
  attributes :id, :project_id, :issue_id, :created_by_id, :assigned_to_id, :title,
             :description, :priority, :status, :due_date, :created_at, :updated_at
end
