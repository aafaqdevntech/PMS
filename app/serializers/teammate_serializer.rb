class TeammateSerializer < ActiveModel::Serializer
  attributes :id, :username, :email, :full_name, :role, :job_position, :image_url

  def full_name
    object.profile&.full_name
  end

  def image_url
    object.profile&.image_url
  end

  def role
    object.employment_detail&.role
  end

  def job_position
    object.employment_detail&.job_position
  end
end
