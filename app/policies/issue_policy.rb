class IssuePolicy < ApplicationPolicy
  # Issues are the one resource admins don't manage: they raise nothing,
  # close nothing, and edit nothing. They read, and that's all.
  def index? = user.admin? || my_team_id.present?
  def show? = user.admin? || same_team?
  def create? = !user.admin? && same_team?
  def update? = owner? && record.open?
  def destroy? = owner? && record.open?
  def resolve? = team_lead? && record.open?
  def reject? = resolve?

  def owner?
    !user.admin? && record.raised_by_id == user.id
  end

  # The team's designated lead (teams.team_lead_id) — deliberately not
  # employment_details.role == team_lead, which can name a different person.
  def team_lead?
    !user.admin? && record.project.team&.team_lead_id == user.id
  end

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
