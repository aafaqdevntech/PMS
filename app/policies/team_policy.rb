class TeamPolicy < ApplicationPolicy
  # Not specified in the original brief: any authenticated user can view teams
  # (they need to see their own team), but only admins manage them.
  def index? = true
  def show? = true
  def create? = user.admin?
  def update? = user.admin?
  def destroy? = user.admin?

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
