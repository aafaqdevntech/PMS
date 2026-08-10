class CommentSerializer < ActiveModel::Serializer
  attributes :id, :user_id, :commentable_type, :commentable_id, :body, :created_at, :updated_at
end
