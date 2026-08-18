class Issue < ApplicationRecord
  belongs_to :project
  belongs_to :raised_by, class_name: "User"

  # Work derived from an issue outlives it.
  has_many :tasks, dependent: :nullify

  # Unlike tasks, a notification is meaningless without the issue it's
  # about. In practice this only ever fires for an admin's moderation
  # delete of a closed issue, since destroy is otherwise tightly guarded.
  has_many :notifications, dependent: :destroy

  enum :status, { open: 0, resolved: 1, rejected: 2 }

  # Lengths mirror the check constraints on the table, so over-long input is
  # a 422 here rather than a constraint violation at the database.
  validates :title, presence: true, length: { maximum: 255 }
  validates :description, length: { maximum: 5000 }
  validates :resolution_note, length: { maximum: 5000 }
  validate :project_active, on: :create
  validate :raiser_belongs_to_project_team, on: :create
  validate :resolution_note_matches_status
  validate :locked_once_closed, on: :update

  before_destroy :abort_unless_open

  # Set by IssuesController#destroy so the terminal lock below can tell an
  # admin's moderation delete from anyone else's. Not persisted.
  attr_accessor :destroyed_by

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

  # Closing an issue makes it permanent for the team that raised it. Admins
  # moderate above that line and can delete a closed issue outright — the only
  # exception to the terminal rule, and deliberately a delete rather than an
  # edit, since locked_once_closed still freezes the fields for everyone.
  def abort_unless_open
    return if open? || destroyed_by&.admin?

    errors.add(:base, "is #{status} and can no longer be deleted")
    throw(:abort)
  end
end
