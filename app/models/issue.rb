class Issue < ApplicationRecord
  belongs_to :project
  belongs_to :raised_by, class_name: "User"

  enum :status, { open: 0, resolved: 1, rejected: 2 }

  validates :title, presence: true
  validate :project_active, on: :create
  validate :raiser_belongs_to_project_team, on: :create
  validate :resolution_note_matches_status
  validate :locked_once_closed, on: :update

  before_destroy :abort_unless_open

  private

  # Issues are only raised against a team's in-flight work. Checked on
  # create only: a project moving to onhold/archived later must not strand
  # its open issues with no way for the lead to close them out.
  def project_active
    return if project.blank?

    errors.add(:project, "must be active to raise an issue against it") unless project.active?
  end

  def raiser_belongs_to_project_team
    return if project.blank? || raised_by.blank?

    unless project.team_id.present? && project.team_id == raised_by.employment_detail&.team_id
      errors.add(:raised_by, "must be a member of the project's team")
    end
  end

  # resolution_note is the team lead's justification for closing an issue,
  # so it's required when closing and meaningless while the issue is open.
  def resolution_note_matches_status
    if open?
      errors.add(:resolution_note, "can only be set when resolving or rejecting") if resolution_note.present?
    elsif resolution_note.blank?
      errors.add(:resolution_note, "is required to resolve or reject an issue")
    end
  end

  # Resolved/rejected is terminal: once closed, nothing about the issue may
  # change again, for anyone.
  def locked_once_closed
    return if status_in_database == "open"

    errors.add(:base, "is #{status_in_database} and can no longer be changed")
  end

  def abort_unless_open
    return if open?

    errors.add(:base, "is #{status} and can no longer be deleted")
    throw(:abort)
  end
end
