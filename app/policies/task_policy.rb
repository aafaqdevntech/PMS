class TaskPolicy < ApplicationPolicy
  # Tasks are lead-managed: the project team's lead creates, edits, assigns
  # and reviews them, the assignee drives the work statuses, and the rest of
  # the team reads. Admins, as with issues, read everything and can delete as
  # moderators, but take no part in the workflow itself.
  def index? = user.admin? || my_team_id.present?
  def show? = user.admin? || same_team?
  def create? = lead?
  def update? = lead?
  def destroy? = lead? || user.admin?
  def assign? = lead?
  def unassign? = lead?
  def change_status? = lead? || assignee?

  # Nothing stops an admin from being named a team's lead, so the admin
  # exclusion stays here rather than in the model helpers.
  def lead? = !user.admin? && record.led_by?(user)
  def assignee? = !user.admin? && record.assignee?(user)

  def same_team?
    my_team_id.present? && my_team_id == record.project.team_id
  end

  def my_team_id
    user.employment_detail&.team_id
  end

  class Scope < Scope
    def resolve
      return scope.all if user.admin?

      team_id = user.employment_detail&.team_id
      team_id ? scope.joins(:project).where(projects: { team_id: team_id }) : scope.none
    end
  end
end
