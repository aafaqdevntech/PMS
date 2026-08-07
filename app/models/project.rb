class Project < ApplicationRecord
  belongs_to :team, optional: true
  belongs_to :created_by, class_name: "User"

  has_many :issues, dependent: :destroy

  enum :status, { planning: 0, active: 1, onhold: 2, completed: 3, archived: 4 }

  validates :title, presence: true
  validate :end_date_after_start_date
  validate :status_requires_team, unless: -> { planning? || archived? }

  before_validation :auto_archive_if_unassigned
  before_validation :set_start_date_on_first_activation

  private

  def end_date_after_start_date
    return if start_date.blank? || end_date.blank?

    errors.add(:end_date, "must be after start date") if end_date <= start_date
  end

  def status_requires_team
    errors.add(:team, "must be assigned before this status can be set") if team_id.blank?
  end

  # Unassigning a team always archives the project. Assigning one back
  # never auto-reverts this — archived is a stable state once entered.
  def auto_archive_if_unassigned
    self.status = :archived if team_id.blank? && team_id_was.present?
  end

  # Only the first activation sets start_date; later transitions leave it alone.
  def set_start_date_on_first_activation
    self.start_date = Date.current if status_changed? && active? && start_date.blank?
  end
end
