class UserPolicy < ApplicationPolicy
  def index? = user.admin? || my_team_id.present?
  def show? = admin_or_owner? || teammate?
  def create? = user.admin?
  def update? = user.admin?
  def destroy? = user.admin?

  def owns_record?
    record == user
  end

  # Team members can see each other (limited fields — see TeammateSerializer).
  def teammate?
    my_team_id.present? && my_team_id == record.employment_detail&.team_id
  end

  def my_team_id
    user.employment_detail&.team_id
  end

  class Scope < Scope
    def resolve
      return scope.all if user.admin?

      team_id = user.employment_detail&.team_id
      team_id ? scope.joins(:employment_detail).where(employment_details: { team_id: team_id }) : scope.where(id: user.id)
    end
  end
end
