class ProjectPolicy < ApplicationPolicy
  def index? = user.admin? || my_team_id.present?
  def show? = user.admin? || teammate_project?
  def create? = user.admin?
  def update? = user.admin?
  def destroy? = user.admin?
  def assign_team? = user.admin?
  def unassign_team? = user.admin?

  def teammate_project?
    my_team_id.present? && my_team_id == record.team_id
  end

  def my_team_id
    user.employment_detail&.team_id
  end

  class Scope < Scope
    def resolve
      return scope.all if user.admin?

      team_id = user.employment_detail&.team_id
      team_id ? scope.where(team_id: team_id) : scope.none
    end
  end
end
