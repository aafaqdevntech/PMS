class TaskSerializer < ActiveModel::Serializer
  attributes :id, :project_id, :issue_id, :created_by_id, :created_by_name, :assigned_to_id,
             :assigned_to_name, :title, :description, :priority, :status, :due_date,
             :created_at, :updated_at

  def created_by_name
    object.created_by&.profile&.full_name
  end

  def assigned_to_name
    object.assigned_to&.profile&.full_name
  end
end
