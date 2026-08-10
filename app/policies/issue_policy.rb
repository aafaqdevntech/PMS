class IssuePolicy < ApplicationPolicy
  # Admins don't take part in issues — they raise nothing, close nothing and
  # edit nothing. They read everything, and they moderate: an admin can delete
  # any issue at any status, which is the one way past the terminal lock (see
  # Issue#abort_unless_open). The raiser only gets to delete while it's open.
  def index? = user.admin? || my_team_id.present?
  def show? = user.admin? || same_team?
  def create? = !user.admin? && same_team?
  def update? = owner? && record.open?
  def destroy? = user.admin? || (owner? && record.open?)
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
