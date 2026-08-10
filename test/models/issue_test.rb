require "test_helper"

class IssueTest < ActiveSupport::TestCase
  setup do
    @team = Team.create!(name: "Team A")
    @other_team = Team.create!(name: "Team B")

    @admin = User.create!(username: "admin", email: "admin@example.com", password: "password123")
    EmploymentDetail.create!(user: @admin, role: :admin, job_position: "Admin", joined_at: Time.current)

    @lead = User.create!(username: "lead", email: "lead@example.com", password: "password123")
    EmploymentDetail.create!(user: @lead, team: @team, role: :team_lead, job_position: "Lead", joined_at: Time.current)
    @team.update!(team_lead: @lead)

    @member = User.create!(username: "member", email: "member@example.com", password: "password123")
    EmploymentDetail.create!(user: @member, team: @team, role: :member, job_position: "Engineer", joined_at: Time.current)

    @outsider = User.create!(username: "outsider", email: "outsider@example.com", password: "password123")
    EmploymentDetail.create!(user: @outsider, team: @other_team, role: :member, job_position: "Engineer", joined_at: Time.current)

    @project = Project.create!(title: "Project A", team: @team, created_by: @admin, status: :active)
  end

  def new_issue(attrs = {})
    Issue.new({ title: "Bug", project: @project, raised_by: @member }.merge(attrs))
  end

  # --- basic validations ---

  test "an issue from a project team member is valid" do
    assert new_issue.valid?
  end

  test "title must be present and at most 255 characters" do
    blank = new_issue(title: "")
    assert_not blank.valid?
    assert_includes blank.errors[:title], "can't be blank"

    long = new_issue(title: "a" * 256)
    assert_not long.valid?
    assert_includes long.errors[:title], "is too long (maximum is 255 characters)"
  end

  test "description is optional but capped at 5000 characters" do
    assert new_issue(description: nil).valid?

    long = new_issue(description: "a" * 5001)
    assert_not long.valid?
    assert_includes long.errors[:description], "is too long (maximum is 5000 characters)"
  end

  test "resolution_note is capped at 5000 characters" do
    issue = new_issue(status: :resolved, resolution_note: "a" * 5001)
    assert_not issue.valid?
    assert_includes issue.errors[:resolution_note], "is too long (maximum is 5000 characters)"
  end

  # --- project_active (on create) ---

  test "cannot raise an issue against a project that is not active" do
    planning = Project.create!(title: "Planning", team: @team, created_by: @admin)
    issue = new_issue(project: planning)
    assert_not issue.valid?
    assert_includes issue.errors[:project], "must be active to raise an issue against it"
  end

  test "project_active is only checked on create" do
    issue = new_issue
    issue.save!
    @project.update!(status: :onhold)

    issue.title = "Edited"
    assert issue.valid?
  end

  # --- raiser_belongs_to_project_team (on create) ---

  test "the raiser must belong to the project's team" do
    issue = new_issue(raised_by: @outsider)
    assert_not issue.valid?
    assert_includes issue.errors[:raised_by], "must be a member of the project's team"
  end

  test "an admin, who has no team, cannot raise an issue" do
    issue = new_issue(raised_by: @admin)
    assert_not issue.valid?
    assert_includes issue.errors[:raised_by], "must be a member of the project's team"
  end

  test "raiser_belongs_to_project_team is only checked on create" do
    issue = new_issue
    issue.save!
    @member.employment_detail.update!(team: @other_team)

    issue.title = "Edited"
    assert issue.valid?
  end

  # --- resolution_note_matches_status ---

  test "resolution_note must be blank while the issue is open" do
    issue = new_issue(resolution_note: "premature")
    assert_not issue.valid?
    assert_includes issue.errors[:resolution_note], "can only be set when resolving or rejecting"
  end

  test "resolution_note is required to resolve or reject" do
    resolved = new_issue(status: :resolved)
    assert_not resolved.valid?
    assert_includes resolved.errors[:resolution_note], "is required to resolve or reject an issue"

    rejected = new_issue(status: :rejected)
    assert_not rejected.valid?
    assert_includes rejected.errors[:resolution_note], "is required to resolve or reject an issue"
  end

  test "resolving or rejecting with a resolution note is valid" do
    assert new_issue(status: :resolved, resolution_note: "Fixed").valid?
    assert new_issue(status: :rejected, resolution_note: "Not a bug").valid?
  end

  # --- locked_once_closed (on update) ---

  test "a resolved issue rejects any further update, even to unrelated fields" do
    issue = new_issue
    issue.save!
    issue.update!(status: :resolved, resolution_note: "Fixed")

    issue.title = "Edited title"
    assert_not issue.valid?
    assert_includes issue.errors[:base], "is resolved and can no longer be changed"
  end

  test "a rejected issue is equally locked" do
    issue = new_issue
    issue.save!
    issue.update!(status: :rejected, resolution_note: "Not valid")

    issue.description = "new description"
    assert_not issue.valid?
    assert_includes issue.errors[:base], "is rejected and can no longer be changed"
  end

  test "an open issue can be freely updated" do
    issue = new_issue
    issue.save!

    issue.title = "Edited"
    assert issue.valid?
  end

  # --- abort_unless_open (before_destroy) ---

  test "an open issue can be destroyed" do
    issue = new_issue
    issue.save!
    assert issue.destroy
    assert_not Issue.exists?(issue.id)
  end

  test "a closed issue cannot be destroyed by default" do
    issue = new_issue
    issue.save!
    issue.update!(status: :resolved, resolution_note: "Fixed")

    result = issue.destroy
    assert_equal false, result
    assert_includes issue.errors[:base], "is resolved and can no longer be deleted"
    assert Issue.exists?(issue.id)
  end

  test "a closed issue can be destroyed when destroyed_by is an admin" do
    issue = new_issue
    issue.save!
    issue.update!(status: :resolved, resolution_note: "Fixed")

    issue.destroyed_by = @admin
    assert issue.destroy
    assert_not Issue.exists?(issue.id)
  end

  test "a closed issue is still blocked when destroyed_by is a non-admin" do
    issue = new_issue
    issue.save!
    issue.update!(status: :resolved, resolution_note: "Fixed")

    issue.destroyed_by = @member
    result = issue.destroy
    assert_equal false, result
    assert Issue.exists?(issue.id)
  end

  test "destroyed_by left nil is treated as non-admin and stays blocked" do
    issue = new_issue
    issue.save!
    issue.update!(status: :rejected, resolution_note: "No")

    result = issue.destroy
    assert_equal false, result
    assert Issue.exists?(issue.id)
  end

  # --- dependent associations ---

  test "destroying the project destroys its issues" do
    issue = new_issue
    issue.save!

    assert_difference("Issue.count", -1) { @project.destroy! }
  end

  test "destroying an issue nullifies its tasks' issue_id and destroys its comments" do
    issue = new_issue
    issue.save!
    task = Task.create!(title: "T", description: "d", project: @project, created_by: @lead, issue: issue)
    comment = Comment.create!(commentable: issue, user: @member, body: "hi")

    issue.destroy!

    assert task.reload.persisted?
    assert_nil task.issue_id
    assert_nil Comment.find_by(id: comment.id)
  end
end
