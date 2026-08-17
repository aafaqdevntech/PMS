require "test_helper"

class TaskTest < ActiveSupport::TestCase
  setup do
    @team = Team.create!(name: "Team A")
    @other_team = Team.create!(name: "Team B")

    @admin = User.create!(username: "admin", email: "admin@example.com", password: "password123")
    EmploymentDetail.create!(user: @admin, role: :admin, job_position: "Admin", joined_at: Time.current)

    @lead = User.create!(username: "lead", email: "lead@example.com", password: "password123")
    EmploymentDetail.create!(user: @lead, team: @team, role: :team_lead, job_position: "Lead", joined_at: Time.current)
    @team.update!(team_lead: @lead)

    # role: team_lead, but NOT teams.team_lead_id — must have no special power.
    @fake_lead = User.create!(username: "fake_lead", email: "fake_lead@example.com", password: "password123")
    EmploymentDetail.create!(user: @fake_lead, team: @team, role: :team_lead, job_position: "Lead", joined_at: Time.current)

    @assignee = User.create!(username: "assignee", email: "assignee@example.com", password: "password123")
    EmploymentDetail.create!(user: @assignee, team: @team, role: :member, job_position: "Engineer", joined_at: Time.current)

    @teammate = User.create!(username: "teammate", email: "teammate@example.com", password: "password123")
    EmploymentDetail.create!(user: @teammate, team: @team, role: :member, job_position: "Engineer", joined_at: Time.current)

    @outsider = User.create!(username: "outsider", email: "outsider@example.com", password: "password123")
    EmploymentDetail.create!(user: @outsider, team: @other_team, role: :member, job_position: "Engineer", joined_at: Time.current)

    @project = Project.create!(title: "Project A", team: @team, created_by: @admin, status: :active)
    @issue = Issue.create!(title: "Bug", description: "It breaks", project: @project, raised_by: @assignee)
  end

  def new_task(attrs = {})
    Task.new({ title: "Task", description: "details", project: @project, created_by: @lead }.merge(attrs))
  end

  # --- basic validations ---

  test "a task created by the project's real lead is valid" do
    assert new_task.valid?
  end

  test "title must be present and at most 255 characters" do
    blank = new_task(title: "")
    assert_not blank.valid?
    assert_includes blank.errors[:title], "can't be blank"

    long = new_task(title: "a" * 256)
    assert_not long.valid?
    assert_includes long.errors[:title], "is too long (maximum is 255 characters)"
  end

  test "description is required (unlike Issue/Project) and capped at 5000 characters" do
    blank = new_task(description: "")
    assert_not blank.valid?
    assert_includes blank.errors[:description], "can't be blank"

    long = new_task(description: "b" * 5001)
    assert_not long.valid?
    assert_includes long.errors[:description], "is too long (maximum is 5000 characters)"
  end

  test "an unparseable due_date is rejected instead of silently becoming nil" do
    task = new_task(due_date: "not-a-date")
    assert_not task.valid?
    assert_includes task.errors[:due_date], "is not a valid date"
  end

  test "a valid or blank due_date is accepted" do
    assert new_task(due_date: "2026-09-01").valid?
    assert new_task(due_date: nil).valid?
  end

  # --- project_active (on create) ---

  test "cannot create a task against a project that is not active" do
    planning = Project.create!(title: "Planning", team: @team, created_by: @admin)
    task = new_task(project: planning)
    assert_not task.valid?
    assert_includes task.errors[:project], "must be active to create a task against it"
  end

  test "project_active is only checked on create, not on update" do
    task = new_task
    task.save!
    @project.update!(status: :onhold)

    task.title = "Edited"
    assert task.valid?
  end

  # --- creator_leads_project_team (on create) ---

  test "a role-only team_lead without teams.team_lead_id cannot create a task" do
    task = new_task(created_by: @fake_lead)
    assert_not task.valid?
    assert_includes task.errors[:created_by], "must be the lead of the project's team"
  end

  test "a regular member cannot create a task" do
    task = new_task(created_by: @assignee)
    assert_not task.valid?
    assert_includes task.errors[:created_by], "must be the lead of the project's team"
  end

  test "creator_leads_project_team is only checked on create" do
    task = new_task
    task.save!
    @team.update!(team_lead: @assignee)

    task.title = "Edited"
    assert task.valid?
  end

  # --- assignee_belongs_to_project_team (only when assigned_to_id changes) ---

  test "an assignee outside the project's team is rejected" do
    task = new_task(assigned_to: @outsider, status: :assigned)
    assert_not task.valid?
    assert_includes task.errors[:assigned_to], "must be a member of the project's team"
  end

  test "an assignee inside the project's team is accepted" do
    assert new_task(assigned_to: @assignee, status: :assigned).valid?
  end

  test "assignee_belongs_to_project_team only fires when the assignee changes" do
    task = new_task(assigned_to: @assignee, status: :assigned)
    task.save!
    @project.update!(team: nil) # auto-archives the project; assignee's team link is untouched

    task.title = "Edited"
    assert task.valid?
  end

  # --- issue_belongs_to_project (only when issue_id changes) ---

  test "linking a task to an issue from a different project is rejected" do
    member = User.create!(username: "member2", email: "member2@example.com", password: "password123")
    EmploymentDetail.create!(user: member, team: @other_team, role: :member, job_position: "Engineer", joined_at: Time.current)
    other_project = Project.create!(title: "Other", team: @other_team, created_by: @admin, status: :active)
    other_issue = Issue.create!(title: "Their bug", project: other_project, raised_by: member)

    task = new_task(issue: other_issue)
    assert_not task.valid?
    assert_includes task.errors[:issue], "must belong to the same project"
  end

  test "linking a task to an issue on the same project is accepted" do
    assert new_task(issue: @issue).valid?
  end

  # --- assignment_matches_status ---

  test "a status other than unassigned requires an assignee" do
    task = new_task(status: :assigned)
    assert_not task.valid?
    assert_includes task.errors[:assigned_to], "must be set before the task can leave the unassigned status"
  end

  test "an assignee requires a status other than unassigned" do
    task = new_task(assigned_to: @assignee, status: :unassigned)
    assert_not task.valid?
    assert_includes task.errors[:status], "cannot be unassigned while the task has an assignee"
  end

  test "unassigned with no assignee is valid" do
    assert new_task(status: :unassigned).valid?
  end

  # --- status_transition_allowed (on update, only when status_changed_by is set) ---

  test "status_transition_allowed is skipped entirely when status_changed_by is not set" do
    task = new_task(assigned_to: @assignee, status: :assigned)
    task.save!

    task.status = :completed # would otherwise be an illegal jump
    assert task.valid?
  end

  test "the assignee can move an assigned task to working, but not straight to on_hold" do
    task = new_task(assigned_to: @assignee, status: :assigned)
    task.save!

    task.status_changed_by = @assignee
    task.status = :working
    assert task.valid?
    task.save!

    dup = Task.find(task.id)
    dup.status_changed_by = @assignee
    dup.status = :on_hold
    assert_not dup.valid?
    assert_includes dup.errors[:status], "cannot be changed from working to on_hold by this user"
  end

  test "the lead can put an assigned task on_hold, but cannot skip straight to working" do
    task = new_task(assigned_to: @assignee, status: :assigned)
    task.save!

    task.status_changed_by = @lead
    task.status = :on_hold
    assert task.valid?

    dup = Task.find(task.id)
    dup.status_changed_by = @lead
    dup.status = :working
    assert_not dup.valid?
  end

  test "a third party cannot change status at all" do
    task = new_task(assigned_to: @assignee, status: :assigned)
    task.save!

    task.status_changed_by = @teammate
    task.status = :working
    assert_not task.valid?

    task.status_changed_by = @fake_lead
    assert_not task.valid?
  end

  test "ready_for_review can move to returned, completed, or on_hold, only by the lead" do
    task = new_task(assigned_to: @assignee, status: :ready_for_review)
    task.save!

    %w[returned completed on_hold].each do |target|
      dup = Task.find(task.id)
      dup.status_changed_by = @lead
      dup.status = target
      assert dup.valid?, "expected #{target} to be allowed from ready_for_review by the lead"
    end

    dup = Task.find(task.id)
    dup.status_changed_by = @assignee
    dup.status = "completed"
    assert_not dup.valid?, "the assignee cannot move ready_for_review to completed"
  end

  test "on_hold returns to assigned only, and only by the lead" do
    task = new_task(assigned_to: @assignee, status: :on_hold)
    task.save!

    task.status_changed_by = @lead
    task.status = :assigned
    assert task.valid?

    dup = Task.find(task.id)
    dup.status_changed_by = @assignee
    dup.status = :assigned
    assert_not dup.valid?
  end

  test "completed can be reopened to returned or on_hold, only by the lead" do
    task = new_task(assigned_to: @assignee, status: :completed)
    task.save!

    %w[returned on_hold].each do |target|
      dup = Task.find(task.id)
      dup.status_changed_by = @lead
      dup.status = target
      assert dup.valid?
    end
  end

  test "returned can go to working or ready_for_review by the assignee, or on_hold by the lead" do
    task = new_task(assigned_to: @assignee, status: :returned)
    task.save!

    working = Task.find(task.id)
    working.status_changed_by = @assignee
    working.status = :working
    assert working.valid?

    review = Task.find(task.id)
    review.status_changed_by = @assignee
    review.status = :ready_for_review
    assert review.valid?

    on_hold = Task.find(task.id)
    on_hold.status_changed_by = @lead
    on_hold.status = :on_hold
    assert on_hold.valid?
  end

  test "a lead who is also the assignee gets the union of both transition tables" do
    task = new_task(assigned_to: @lead, status: :assigned)
    task.save!

    task.status_changed_by = @lead
    task.status = :working # assignee-only transition
    assert task.valid?
    task.save!

    task.status_changed_by = @lead
    task.status = :on_hold # lead-only transition, from "working"
    assert task.valid?
  end

  test "repeating the same status is rejected" do
    task = new_task(assigned_to: @assignee, status: :assigned)
    task.save!

    task.status_changed_by = @assignee
    task.status = :assigned
    assert_not task.valid?
  end

  # --- enum validation (validate: true keeps bad input out of the ArgumentError path) ---

  test "an unknown priority is invalid rather than raising" do
    task = new_task
    task.priority = "urgent"
    assert_not task.valid?
    assert_includes task.errors[:priority], "is not included in the list"
  end

  test "an unknown status is invalid rather than raising" do
    task = new_task
    task.status = "bogus"
    assert_not task.valid?
    assert_includes task.errors[:status], "is not included in the list"
  end

  # --- helper methods ---

  test "led_by? checks the project's team_lead_id, not the employment_detail role" do
    task = new_task
    task.save!

    assert task.led_by?(@lead)
    assert_not task.led_by?(@fake_lead)
    assert_not task.led_by?(@assignee)
  end

  test "assignee? checks assigned_to_id" do
    task = new_task(assigned_to: @assignee, status: :assigned)
    task.save!

    assert task.assignee?(@assignee)
    assert_not task.assignee?(@lead)
  end

  # --- dependent associations ---

  test "destroying the project destroys its tasks" do
    task = new_task
    task.save!

    assert_difference("Task.count", -1) { @project.destroy! }
  end

  test "destroying the issue nullifies its tasks' issue_id, leaving the task in place" do
    task = new_task(issue: @issue)
    task.save!

    @issue.destroy!

    assert task.reload.persisted?
    assert_nil task.issue_id
  end
end
