class TeammateNameSerializer < ActiveModel::Serializer
  attributes :id, :full_name

  def full_name
    object.profile&.full_name
  end
end
