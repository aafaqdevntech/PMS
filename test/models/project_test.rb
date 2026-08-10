require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  setup do
    @team = Team.create!(name: "Team A")
    @other_team = Team.create!(name: "Team B")

    @admin = User.create!(username: "admin", email: "admin@example.com", password: "password123")
    EmploymentDetail.create!(user: @admin, role: :admin, job_position: "Admin", joined_at: Time.current)
  end

  def new_project(attrs = {})
    Project.new({ title: "Project", created_by: @admin }.merge(attrs))
  end

  # --- basic validations ---

  test "a project with just a title and creator is valid" do
    assert new_project.valid?
  end

  test "title must be present and at most 255 characters" do
    blank = new_project(title: "")
    assert_not blank.valid?
    assert_includes blank.errors[:title], "can't be blank"

    long = new_project(title: "a" * 256)
    assert_not long.valid?
    assert_includes long.errors[:title], "is too long (maximum is 255 characters)"
  end

  test "description is optional but capped at 5000 characters" do
    assert new_project(description: nil).valid?

    long = new_project(description: "a" * 5001)
    assert_not long.valid?
    assert_includes long.errors[:description], "is too long (maximum is 5000 characters)"
  end

  # --- end_date_after_start_date ---

  test "end_date must be strictly after start_date" do
    same_day = new_project(start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 1, 1))
    assert_not same_day.valid?
    assert_includes same_day.errors[:end_date], "must be after start date"

    before = new_project(start_date: Date.new(2026, 1, 5), end_date: Date.new(2026, 1, 1))
    assert_not before.valid?

    after = new_project(start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 1, 2))
    assert after.valid?
  end

  test "end_date_after_start_date is skipped when either date is blank" do
    assert new_project(start_date: Date.current, end_date: nil).valid?
    assert new_project(start_date: nil, end_date: Date.current).valid?
  end

  # --- status_requires_team ---

  test "active, onhold, and completed all require a team" do
    %i[active onhold completed].each do |status|
      project = new_project(status: status)
      assert_not project.valid?, "#{status} should require a team"
      assert_includes project.errors[:team], "must be assigned before this status can be set"
    end
  end

  test "planning and archived do not require a team" do
    assert new_project(status: :planning).valid?
    assert new_project(status: :archived).valid?
  end

  test "active with a team assigned is valid" do
    assert new_project(status: :active, team: @team).valid?
  end

  # --- auto_archive_if_unassigned ---

  test "clearing an active project's team auto-archives it" do
    project = new_project(status: :active, team: @team)
    project.save!

    project.update!(team: nil)
    assert_equal "archived", project.status
  end

  test "reassigning a team to an auto-archived project does not un-archive it" do
    project = new_project(status: :active, team: @team)
    project.save!
    project.update!(team: nil)
    assert_equal "archived", project.status

    project.update!(team: @other_team)
    assert_equal "archived", project.status
  end

  test "auto_archive does not fire for a project that never had a team" do
    project = new_project(status: :planning)
    project.save!
    assert_equal "planning", project.status
  end

  # --- set_start_date_on_first_activation ---

  test "the first activation sets start_date to today if it was blank" do
    project = new_project(team: @team)
    project.save!
    assert_nil project.start_date

    travel_to Date.new(2026, 8, 10) do
      project.update!(status: :active)
    end
    assert_equal Date.new(2026, 8, 10), project.start_date
  end

  test "a later reactivation does not overwrite an already-set start_date" do
    project = new_project(team: @team, status: :active)
    project.save!
    original_start = project.start_date
    assert_not_nil original_start

    project.update!(status: :onhold)
    travel_to(Date.current + 10) do
      project.update!(status: :active)
    end
    assert_equal original_start, project.reload.start_date
  end

  test "activation does not overwrite an explicitly set start_date" do
    project = new_project(team: @team, start_date: Date.new(2026, 1, 1))
    project.save!

    project.update!(status: :active)
    assert_equal Date.new(2026, 1, 1), project.start_date
  end

  # --- dependent associations ---

  test "destroying a project destroys its issues and tasks" do
    lead = User.create!(username: "lead", email: "lead@example.com", password: "password123")
    EmploymentDetail.create!(user: lead, team: @team, role: :team_lead, job_position: "Lead", joined_at: Time.current)
    @team.update!(team_lead: lead)

    member = User.create!(username: "member", email: "member@example.com", password: "password123")
    EmploymentDetail.create!(user: member, team: @team, role: :member, job_position: "Engineer", joined_at: Time.current)

    project = new_project(team: @team, status: :active)
    project.save!
    Issue.create!(title: "Bug", project: project, raised_by: member)
    Task.create!(title: "T", description: "d", project: project, created_by: lead)

    assert_difference ["Issue.count", "Task.count"], -1 do
      project.destroy!
    end
  end
end
