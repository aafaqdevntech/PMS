class IssueSerializer < ActiveModel::Serializer
  attributes :id, :project_id, :raised_by_id, :raised_by_name, :title, :description, :status,
             :resolution_note, :created_at, :updated_at

  def raised_by_name
    object.raised_by&.profile&.full_name
  end
end
