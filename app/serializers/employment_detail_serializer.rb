class EmploymentDetailSerializer < ActiveModel::Serializer
  attributes :id, :user_id, :team_id, :role, :job_position, :joined_at
end
