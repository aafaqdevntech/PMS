class CommentPolicy < ApplicationPolicy
  # Comments are the team's conversation: every member of the Issue/Task's
  # team reads and writes, and each author owns their own comment. Admins,
  # as with issues and tasks, don't join in — they read, and they delete.
  def index? = user.admin? || same_team?
  def show? = user.admin? || same_team?
  def create? = !user.admin? && same_team?
  def update? = author?
  def destroy? = author? || user.admin?

  # Nothing stops an admin from also being on a team, so the admin exclusion
  # stays here rather than in the model helper.
  def author? = !user.admin? && record.author?(user)

  # The team is always derived through Issue/Task -> Project -> Team.
  def same_team?
    my_team_id.present? && my_team_id == record.team_id
  end

  def my_team_id
    user.employment_detail&.team_id
  end

  class Scope < Scope
    def resolve
      return scope.all if user.admin?

      team_id = user.employment_detail&.team_id
      return scope.none if team_id.blank?

      # Two subqueries rather than a join: a polymorphic belongs_to can't be
      # joined to its parents in one pass.
      scope.where(commentable_type: "Issue", commentable_id: team_scoped_ids(Issue, team_id))
           .or(scope.where(commentable_type: "Task", commentable_id: team_scoped_ids(Task, team_id)))
    end

    private

    def team_scoped_ids(model, team_id)
      model.joins(:project).where(projects: { team_id: team_id }).select(:id)
    end
  end
end
