class UserDirectorySerializer < ActiveModel::Serializer
  NO_RECORD = "No record!".freeze

  attributes :id, :username, :email, :image_url, :role, :team_name, :job_position, :joined_at

  def image_url
    object.profile&.image_url || NO_RECORD
  end

  def role
    object.employment_detail&.role || NO_RECORD
  end

  def team_name
    object.employment_detail&.team&.name || NO_RECORD
  end

  def job_position
    object.employment_detail&.job_position || NO_RECORD
  end

  def joined_at
    object.employment_detail&.joined_at || NO_RECORD
  end
end
