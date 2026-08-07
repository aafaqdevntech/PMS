class UserSerializer < ActiveModel::Serializer
  attributes :id, :username, :email, :created_at, :updated_at

  has_one :profile
  has_one :employment_detail
end
