require "test_helper"

class TasksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @team = Team.create!(name: "Team A")
    @other_team = Team.create!(name: "Team B")

    @admin = User.create!(username: "admin", email: "admin@example.com", password: "password123")
    EmploymentDetail.create!(user: @admin, role: :admin, job_position: "Admin", joined_at: Time.current)

    @lead = User.create!(username: "lead", email: "lead@example.com", password: "password123")
    EmploymentDetail.create!(user: @lead, team: @team, role: :team_lead, job_position: "Lead", joined_at: Time.current)
    @team.update!(team_lead: @lead)

    @assignee = User.create!(username: "assignee", email: "assignee@example.com", password: "password123")
    EmploymentDetail.create!(user: @assignee, team: @team, role: :member, job_position: "Engineer", joined_at: Time.current)

    @teammate = User.create!(username: "teammate", email: "teammate@example.com", password: "password123")
    EmploymentDetail.create!(user: @teammate, team: @team, role: :member, job_position: "Engineer", joined_at: Time.current)

    # role: team_lead, but NOT teams.team_lead_id — must have no special power.
    @fake_lead = User.create!(username: "fake_lead", email: "fake_lead@example.com", password: "password123")
    EmploymentDetail.create!(user: @fake_lead, team: @team, role: :team_lead, job_position: "Lead", joined_at: Time.current)

    @outsider = User.create!(username: "outsider", email: "outsider@example.com", password: "password123")
    EmploymentDetail.create!(user: @outsider, team: @other_team, role: :member, job_position: "Engineer", joined_at: Time.current)

    @project = Project.create!(title: "Project A", team: @team, created_by: @admin, status: :active)
    @other_project = Project.create!(title: "Project B", team: @other_team, created_by: @admin, status: :active)

    @issue = Issue.create!(title: "Bug", description: "It breaks", project: @project, raised_by: @assignee)
    @task = Task.create!(title: "Ship it", description: "Do the work", project: @project, created_by: @lead)

    @admin_token = login(@admin)
    @lead_token = login(@lead)
    @assignee_token = login(@assignee)
    @teammate_token = login(@teammate)
    @fake_lead_token = login(@fake_lead)
    @outsider_token = login(@outsider)
  end

  # --- creating ---

  test "lead creates a task; created_by is forced and it starts unassigned at normal priority" do
    post "/projects/#{@project.id}/tasks",
      params: { title: "New task", description: "details", created_by_id: @assignee.id,
                status: "completed", assigned_to_id: @assignee.id },
      headers: auth_headers(@lead_token)

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal @lead.id, body["created_by_id"]
    assert_equal "unassigned", body["status"]
    assert_equal "normal", body["priority"]
    assert_nil body["assigned_to_id"]
  end

  test "lead can set priority and due_date at creation" do
    post "/projects/#{@project.id}/tasks",
      params: { title: "Urgent", description: "now", priority: "critical", due_date: "2026-09-01" },
      headers: auth_headers(@lead_token)

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "critical", body["priority"]
    assert_equal "2026-09-01", body["due_date"]
  end

  test "only the project team's designated lead can create a task" do
    [@assignee_token, @teammate_token, @fake_lead_token, @admin_token, @outsider_token].each do |token|
      post "/projects/#{@project.id}/tasks",
        params: { title: "Nope", description: "nope" }, headers: auth_headers(token)
      assert_response :forbidden
    end
  end

  test "cannot create a task on a project that is not active" do
    planning = Project.create!(title: "Planning", team: @team, created_by: @admin)
    post "/projects/#{planning.id}/tasks",
      params: { title: "Too early", description: "details" }, headers: auth_headers(@lead_token)
    assert_response :unprocessable_entity
  end

  test "a task can be created from an issue on the same project" do
    post "/projects/#{@project.id}/tasks",
      params: { title: "From issue", description: "details", issue_id: @issue.id },
      headers: auth_headers(@lead_token)

    assert_response :created
    assert_equal @issue.id, JSON.parse(response.body)["issue_id"]
  end

  test "an issue from another project cannot be linked" do
    other_issue = Issue.create!(title: "Other", project: @other_project, raised_by: @outsider)
    post "/projects/#{@project.id}/tasks",
      params: { title: "Mismatched", description: "details", issue_id: other_issue.id },
      headers: auth_headers(@lead_token)
    assert_response :unprocessable_entity
  end

  test "title and description length limits are enforced as 422, not a database error" do
    post "/projects/#{@project.id}/tasks",
      params: { title: "a" * 256, description: "ok" }, headers: auth_headers(@lead_token)
    assert_response :unprocessable_entity

    post "/projects/#{@project.id}/tasks",
      params: { title: "ok", description: "b" * 5001 }, headers: auth_headers(@lead_token)
    assert_response :unprocessable_entity
  end

  test "description is required" do
    post "/projects/#{@project.id}/tasks", params: { title: "No body" }, headers: auth_headers(@lead_token)
    assert_response :unprocessable_entity
  end

  test "an unknown priority or an unparseable due_date is rejected" do
    post "/projects/#{@project.id}/tasks",
      params: { title: "Bad", description: "details", priority: "urgent" }, headers: auth_headers(@lead_token)
    assert_response :unprocessable_entity

    post "/projects/#{@project.id}/tasks",
      params: { title: "Bad", description: "details", due_date: "tomorrow" }, headers: auth_headers(@lead_token)
    assert_response :unprocessable_entity
  end

  # --- reading ---

  test "teammates and admin can read a task; other teams cannot" do
    [@assignee_token, @teammate_token, @fake_lead_token, @admin_token].each do |token|
      get "/tasks/#{@task.id}", headers: auth_headers(token)
      assert_response :ok
    end

    get "/tasks/#{@task.id}", headers: auth_headers(@outsider_token)
    assert_response :forbidden
  end

  test "index lists only the project's tasks and is blocked for other teams" do
    other_lead = User.create!(username: "other_lead", email: "other_lead@example.com", password: "password123")
    EmploymentDetail.create!(user: other_lead, team: @other_team, role: :team_lead,
                             job_position: "Lead", joined_at: Time.current)
    @other_team.update!(team_lead: other_lead)
    other_task = Task.create!(title: "Elsewhere", description: "details",
                              project: @other_project, created_by: other_lead)

    get "/projects/#{@project.id}/tasks", headers: auth_headers(@assignee_token)
    assert_response :ok
    ids = JSON.parse(response.body).map { |t| t["id"] }
    assert_equal [@task.id], ids
    assert_not_includes ids, other_task.id

    get "/projects/#{@project.id}/tasks", headers: auth_headers(@outsider_token)
    assert_response :forbidden
  end

  # --- flat index (across all projects) ---

  test "GET /tasks: admin sees every task, across every project" do
    other_lead = User.create!(username: "other_lead2", email: "other_lead2@example.com", password: "password123")
    EmploymentDetail.create!(user: other_lead, team: @other_team, role: :team_lead,
                             job_position: "Lead", joined_at: Time.current)
    @other_team.update!(team_lead: other_lead)
    other_task = Task.create!(title: "Elsewhere", description: "details",
                              project: @other_project, created_by: other_lead)

    get "/tasks", headers: auth_headers(@admin_token)
    assert_response :ok
    ids = JSON.parse(response.body).map { |t| t["id"] }
    assert_includes ids, @task.id
    assert_includes ids, other_task.id
  end

  test "GET /tasks: team lead/member sees only their own team's tasks, across every project of that team" do
    second_project = Project.create!(title: "Project C", team: @team, created_by: @admin, status: :active)
    second_task = Task.create!(title: "Also ours", description: "d", project: second_project, created_by: @lead)

    other_lead = User.create!(username: "other_lead3", email: "other_lead3@example.com", password: "password123")
    EmploymentDetail.create!(user: other_lead, team: @other_team, role: :team_lead,
                             job_position: "Lead", joined_at: Time.current)
    @other_team.update!(team_lead: other_lead)
    other_task = Task.create!(title: "Elsewhere", description: "details",
                              project: @other_project, created_by: other_lead)

    get "/tasks", headers: auth_headers(@assignee_token)
    assert_response :ok
    ids = JSON.parse(response.body).map { |t| t["id"] }
    assert_equal [@task.id, second_task.id].sort, ids.sort
    assert_not_includes ids, other_task.id
  end

  test "GET /tasks: a user with no team is forbidden" do
    solo = User.create!(username: "solo_tasks", email: "solo_tasks@example.com", password: "password123")
    EmploymentDetail.create!(user: solo, role: :member, job_position: "Freelancer", joined_at: Time.current)

    get "/tasks", headers: auth_headers(login(solo))
    assert_response :forbidden
  end

  test "index and show include the creator's and assignee's names, resolved from their profiles" do
    Profile.create!(user: @lead, full_name: "Lea Lead")
    Profile.create!(user: @assignee, full_name: "Ada Assignee")
    @task.update!(assigned_to: @assignee, status: :assigned)

    get "/projects/#{@project.id}/tasks", headers: auth_headers(@assignee_token)
    assert_response :ok
    row = JSON.parse(response.body).find { |t| t["id"] == @task.id }
    assert_equal @lead.id, row["created_by_id"]
    assert_equal "Lea Lead", row["created_by_name"]
    assert_equal @assignee.id, row["assigned_to_id"]
    assert_equal "Ada Assignee", row["assigned_to_name"]

    get "/tasks/#{@task.id}", headers: auth_headers(@assignee_token)
    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal "Lea Lead", body["created_by_name"]
    assert_equal "Ada Assignee", body["assigned_to_name"]
  end

  test "created_by_name is null with no profile, and assigned_to_name is null while unassigned" do
    get "/tasks/#{@task.id}", headers: auth_headers(@assignee_token)
    assert_response :ok
    body = JSON.parse(response.body)
    assert_nil body["created_by_name"], "lead has no profile in this test"
    assert_nil body["assigned_to_id"]
    assert_nil body["assigned_to_name"]
  end

  # --- updating and deleting ---

  test "lead edits a task's fields" do
    patch "/tasks/#{@task.id}",
      params: { title: "Edited", description: "new details", priority: "high" },
      headers: auth_headers(@lead_token)

    assert_response :ok
    @task.reload
    assert_equal "Edited", @task.title
    assert_equal "high", @task.priority
  end

  test "update cannot change status or the assignee" do
    patch "/tasks/#{@task.id}",
      params: { status: "completed", assigned_to_id: @assignee.id }, headers: auth_headers(@lead_token)

    assert_response :ok
    @task.reload
    assert_equal "unassigned", @task.status
    assert_nil @task.assigned_to_id
  end

  test "nobody but the lead can edit a task" do
    [@assignee_token, @teammate_token, @fake_lead_token, @admin_token, @outsider_token].each do |token|
      patch "/tasks/#{@task.id}", params: { title: "Hijack" }, headers: auth_headers(token)
      assert_response :forbidden
    end
  end

  test "nobody but the lead and an admin can delete a task" do
    [@assignee_token, @teammate_token, @fake_lead_token, @outsider_token].each do |token|
      delete "/tasks/#{@task.id}", headers: auth_headers(token)
      assert_response :forbidden
    end
    assert Task.exists?(@task.id)
  end

  test "lead can delete a task" do
    delete "/tasks/#{@task.id}", headers: auth_headers(@lead_token)
    assert_response :no_content
  end

  test "an admin can delete any task, on any team and in any status" do
    @other_team.update!(team_lead: @outsider)
    other = Task.create!(title: "Theirs", description: "Other team", project: @other_project,
                         created_by: @outsider)
    @task.update!(assigned_to: @assignee, status: :working)

    delete "/tasks/#{@task.id}", headers: auth_headers(@admin_token)
    assert_response :no_content

    delete "/tasks/#{other.id}", headers: auth_headers(@admin_token)
    assert_response :no_content
  end

  # --- assigning ---

  test "lead assigns a task to a team member" do
    post "/tasks/#{@task.id}/assign", params: { assigned_to_id: @assignee.id }, headers: auth_headers(@lead_token)

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal @assignee.id, body["assigned_to_id"]
    assert_equal "assigned", body["status"]
  end

  test "lead can park a task on hold while assigning it" do
    post "/tasks/#{@task.id}/assign",
      params: { assigned_to_id: @assignee.id, status: "on_hold" }, headers: auth_headers(@lead_token)

    assert_response :ok
    assert_equal "on_hold", JSON.parse(response.body)["status"]
  end

  test "assign only accepts the assigned and on_hold statuses" do
    post "/tasks/#{@task.id}/assign",
      params: { assigned_to_id: @assignee.id, status: "completed" }, headers: auth_headers(@lead_token)

    assert_response :unprocessable_entity
    assert_equal "unassigned", @task.reload.status
  end

  test "a task cannot be assigned to someone outside the project's team" do
    post "/tasks/#{@task.id}/assign", params: { assigned_to_id: @outsider.id }, headers: auth_headers(@lead_token)
    assert_response :unprocessable_entity

    post "/tasks/#{@task.id}/assign", headers: auth_headers(@lead_token)
    assert_response :unprocessable_entity
  end

  test "lead can reassign a task to another member" do
    post "/tasks/#{@task.id}/assign", params: { assigned_to_id: @assignee.id }, headers: auth_headers(@lead_token)
    post "/tasks/#{@task.id}/assign", params: { assigned_to_id: @teammate.id }, headers: auth_headers(@lead_token)

    assert_response :ok
    assert_equal @teammate.id, JSON.parse(response.body)["assigned_to_id"]
  end

  test "unassign clears the assignee and returns the task to the unassigned pool" do
    post "/tasks/#{@task.id}/assign", params: { assigned_to_id: @assignee.id }, headers: auth_headers(@lead_token)

    delete "/tasks/#{@task.id}/unassign", headers: auth_headers(@lead_token)
    assert_response :ok
    body = JSON.parse(response.body)
    assert_nil body["assigned_to_id"]
    assert_equal "unassigned", body["status"]
  end

  test "only the lead can assign or unassign" do
    [@assignee_token, @teammate_token, @fake_lead_token, @admin_token, @outsider_token].each do |token|
      post "/tasks/#{@task.id}/assign", params: { assigned_to_id: @assignee.id }, headers: auth_headers(token)
      assert_response :forbidden

      delete "/tasks/#{@task.id}/unassign", headers: auth_headers(token)
      assert_response :forbidden
    end
  end

  # --- the status workflow ---

  test "assignee moves an assigned task through working and ready for review" do
    assign_to(@assignee)

    change_status("working", @assignee_token)
    assert_response :ok
    assert_equal "working", JSON.parse(response.body)["status"]

    change_status("ready_for_review", @assignee_token)
    assert_response :ok
    assert_equal "ready_for_review", JSON.parse(response.body)["status"]
  end

  test "lead completes a task that is ready for review" do
    assign_to(@assignee)
    change_status("working", @assignee_token)
    change_status("ready_for_review", @assignee_token)

    change_status("completed", @lead_token)
    assert_response :ok
    assert_equal "completed", @task.reload.status
  end

  test "lead returns a reviewed task and the assignee picks it back up" do
    assign_to(@assignee)
    change_status("working", @assignee_token)
    change_status("ready_for_review", @assignee_token)

    change_status("returned", @lead_token)
    assert_response :ok

    change_status("working", @assignee_token)
    assert_response :ok

    change_status("ready_for_review", @assignee_token)
    assert_response :ok
    assert_equal "ready_for_review", @task.reload.status
  end

  test "a returned task can go straight back to review" do
    assign_to(@assignee)
    change_status("working", @assignee_token)
    change_status("ready_for_review", @assignee_token)
    change_status("returned", @lead_token)

    change_status("ready_for_review", @assignee_token)
    assert_response :ok
  end

  test "lead can reopen a completed task" do
    assign_to(@assignee)
    change_status("working", @assignee_token)
    change_status("ready_for_review", @assignee_token)
    change_status("completed", @lead_token)

    change_status("returned", @lead_token)
    assert_response :ok
    assert_equal "returned", @task.reload.status
  end

  test "lead can park and resume an in-flight task" do
    assign_to(@assignee)
    change_status("working", @assignee_token)

    change_status("on_hold", @lead_token)
    assert_response :ok

    change_status("assigned", @lead_token)
    assert_response :ok
    assert_equal "assigned", @task.reload.status
  end

  test "assignee cannot skip review, and cannot restart a task the lead parked" do
    assign_to(@assignee)

    change_status("completed", @assignee_token)
    assert_response :unprocessable_entity

    change_status("on_hold", @lead_token)
    change_status("working", @assignee_token)
    assert_response :unprocessable_entity
    assert_equal "on_hold", @task.reload.status
  end

  test "lead cannot complete a task that has not been through review" do
    assign_to(@assignee)

    change_status("completed", @lead_token)
    assert_response :unprocessable_entity
    assert_equal "assigned", @task.reload.status
  end

  test "a lead assigned to their own task can drive it to completion" do
    assign_to(@lead)

    change_status("working", @lead_token)
    assert_response :ok

    change_status("ready_for_review", @lead_token)
    assert_response :ok

    change_status("completed", @lead_token)
    assert_response :ok
    assert_equal "completed", @task.reload.status
  end

  test "only the lead and the assignee can change a task's status" do
    assign_to(@assignee)

    [@teammate_token, @fake_lead_token, @admin_token, @outsider_token].each do |token|
      change_status("working", token)
      assert_response :forbidden
    end
    assert_equal "assigned", @task.reload.status
  end

  test "an unknown status is rejected with 422" do
    assign_to(@assignee)

    change_status("bogus", @assignee_token)
    assert_response :unprocessable_entity
    assert_equal "assigned", @task.reload.status
  end

  test "repeating the current status is rejected" do
    assign_to(@assignee)

    change_status("assigned", @assignee_token)
    assert_response :unprocessable_entity
  end

  # --- issue linkage ---

  test "deleting an issue leaves its tasks in place with issue_id nulled" do
    task = Task.create!(title: "From issue", description: "details", project: @project,
                        created_by: @lead, issue: @issue)

    delete "/issues/#{@issue.id}", headers: auth_headers(@assignee_token)
    assert_response :no_content

    assert_nil task.reload.issue_id
  end

  private

  def assign_to(user)
    post "/tasks/#{@task.id}/assign", params: { assigned_to_id: user.id }, headers: auth_headers(@lead_token)
  end

  def change_status(status, token)
    patch "/tasks/#{@task.id}/status", params: { status: status }, headers: auth_headers(token)
  end

  def login(user)
    post "/auth/login", params: { login: user.username, password: "password123" }
    JSON.parse(response.body)["access_token"]
  end

  def auth_headers(token)
    { "Authorization" => "Bearer #{token}" }
  end
end
