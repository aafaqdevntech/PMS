class TeamPolicy < ApplicationPolicy
  # Listing (browsing every team) is admin only. Viewing a single team stays
  # open to any authenticated user — they still need to see their own team
  # by id — and only admins manage (create/update/destroy) teams.
  def index? = user.admin?
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
