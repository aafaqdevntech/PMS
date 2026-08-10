class Comment < ApplicationRecord
  # The only two things that can be commented on. Mirrors the check
  # constraint on comments.commentable_type.
  COMMENTABLE_TYPES = %w[Issue Task].freeze

  belongs_to :user
  belongs_to :commentable, polymorphic: true

  validates :body, presence: true, length: { maximum: 5000 }
  validates :commentable_type, inclusion: { in: COMMENTABLE_TYPES }

  # A polymorphic parent gets no database foreign key, so an id pointing at a
  # row that doesn't exist would otherwise be stored happily.
  validate :commentable_exists, if: -> { commentable_id_changed? || commentable_type_changed? }

  # The team that owns the conversation, always derived through
  # Issue/Task -> Project -> Team and never taken from the client.
  def team_id
    commentable&.project&.team_id
  end

  def author?(other) = other.present? && user_id == other.id

  private

  def commentable_exists
    return if commentable_id.blank? || !COMMENTABLE_TYPES.include?(commentable_type)

    errors.add(:commentable, "must exist") if commentable.blank?
  end
end
