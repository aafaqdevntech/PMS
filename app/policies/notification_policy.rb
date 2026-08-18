class NotificationPolicy < ApplicationPolicy
  def index? = true
  def read? = owner?
  def read_all? = true

  def owner?
    record.recipient_id == user.id
  end

  # No admin bypass: admins never participate in issues (see IssuePolicy)
  # and are never a notification recipient, so scope strictly to the
  # current user's own inbox, same as /me/counts.
  class Scope < Scope
    def resolve
      scope.where(recipient_id: user.id)
    end
  end
end
