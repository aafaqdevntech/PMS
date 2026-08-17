class Task < ApplicationRecord
  # Status moves allowed through PATCH /tasks/:id/status, keyed by the task's
  # persisted status. Assigning and unassigning are separate lead actions and
  # are deliberately not part of these tables.
  LEAD_TRANSITIONS = {
    "assigned" => %w[on_hold],
    "working" => %w[on_hold],
    "returned" => %w[on_hold],
    "ready_for_review" => %w[returned completed on_hold],
    "on_hold" => %w[assigned],
    "completed" => %w[returned on_hold]
  }.freeze

  ASSIGNEE_TRANSITIONS = {
    "assigned" => %w[working],
    "working" => %w[ready_for_review],
    "returned" => %w[working ready_for_review]
  }.freeze

  # The lead decides whether assigned work starts now or is parked.
  ASSIGNABLE_STATUSES = %w[assigned on_hold].freeze

  belongs_to :project
  belongs_to :issue, optional: true
  belongs_to :created_by, class_name: "User"
  belongs_to :assigned_to, class_name: "User", optional: true

  # validate: true keeps an unknown value (or a blank one) out of the raw
  # ArgumentError path, so bad input is a 422 like every other bad field.
  enum :priority, { critical: 0, high: 1, medium: 2, normal: 3 }, validate: true
  enum :status, { unassigned: 0, assigned: 1, working: 2, on_hold: 3,
                  ready_for_review: 4, returned: 5, completed: 6 }, validate: true

  # Set by TasksController#change_status so the model can tell a lead's moves
  # from the assignee's. Not persisted.
  attr_accessor :status_changed_by

  validates :title, presence: true, length: { maximum: 255 }
  validates :description, presence: true, length: { maximum: 5000 }
  validate :due_date_parsable
  validate :project_active, on: :create
  validate :creator_leads_project_team, on: :create
  # The team checks only run when the link itself changes: a project that
  # later loses its team would otherwise freeze all of its tasks, leaving no
  # way to even unassign them.
  validate :assignee_belongs_to_project_team, if: -> { assigned_to_id_changed? }
  validate :issue_belongs_to_project, if: -> { issue_id_changed? }
  validate :assignment_matches_status, if: -> { assigned_to_id_changed? || status_changed? }
  validate :status_transition_allowed, on: :update, if: -> { status_changed_by.present? }

  # The project team's designated lead (teams.team_lead_id) — deliberately not
  # employment_details.role == team_lead, which can name a different person.
  def led_by?(user)
    user.present? && project&.team&.team_lead_id.present? && project.team.team_lead_id == user.id
  end

  def assignee?(user)
    user.present? && assigned_to_id.present? && assigned_to_id == user.id
  end

  private

  def team_member?(user)
    project&.team_id.present? && project.team_id == user&.employment_detail&.team_id
  end

  # Tasks are only opened against a team's in-flight work. Checked on create
  # only: a project moving to onhold/archived later must not strand its tasks
  # half-finished with no way to close them out.
  def project_active
    return if project.blank?

    errors.add(:project, "must be active to create a task against it") unless project.active?
  end

  def creator_leads_project_team
    return if project.blank? || created_by.blank?

    errors.add(:created_by, "must be the lead of the project's team") unless led_by?(created_by)
  end

  def assignee_belongs_to_project_team
    return if assigned_to_id.blank?

    errors.add(:assigned_to, "must be a member of the project's team") unless team_member?(assigned_to)
  end

  def issue_belongs_to_project
    return if issue_id.blank?

    errors.add(:issue, "must belong to the same project") unless issue&.project_id == project_id
  end

  # An assignee and a status other than unassigned always travel together.
  def assignment_matches_status
    if assigned_to_id.blank? && !unassigned?
      errors.add(:assigned_to, "must be set before the task can leave the unassigned status")
    elsif assigned_to_id.present? && unassigned?
      errors.add(:status, "cannot be unassigned while the task has an assignee")
    end
  end

  # The lead and the assignee drive different halves of the workflow, and a
  # lead who assigned the task to themself gets both.
  def status_transition_allowed
    from = status_in_database.to_s
    allowed = led_by?(status_changed_by) ? LEAD_TRANSITIONS.fetch(from, []) : []
    allowed |= ASSIGNEE_TRANSITIONS.fetch(from, []) if assignee?(status_changed_by)
    return if allowed.include?(status.to_s)

    errors.add(:status, "cannot be changed from #{from} to #{status} by this user")
  end

  # Rails casts an unparseable date to nil, which would silently drop the
  # field and return 200.
  def due_date_parsable
    errors.add(:due_date, "is not a valid date") if due_date.nil? && due_date_before_type_cast.present?
  end
end
