class EmploymentDetail < ApplicationRecord
  belongs_to :user
  # Optional: admins have no team, and a newly-added employee may not be
  # assigned to one yet.
  belongs_to :team, optional: true

  enum :role, { admin: 0, team_lead: 1, member: 2 }

  validates :user_id, uniqueness: true
  validates :job_position, presence: true
  validates :joined_at, presence: true
  validate :admin_has_no_team

  private

  def admin_has_no_team
    errors.add(:team, "must be blank for admins") if admin? && team.present?
  end
end
