class ProfilePolicy < ApplicationPolicy
  def show? = admin_or_owner?
  def create? = user.admin?
  def update? = user.admin?
  def destroy? = user.admin?

  def owns_record?
    record.user_id == user.id
  end

  class Scope < Scope
    def resolve
      user.admin? ? scope.all : scope.where(user_id: user.id)
    end
  end
end
