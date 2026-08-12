require "test_helper"

class ProjectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @team_a = Team.create!(name: "Team A")
    @team_b = Team.create!(name: "Team B")

    @admin = User.create!(username: "admin", email: "admin@example.com", password: "password123")
    EmploymentDetail.create!(user: @admin, role: :admin, job_position: "Admin", joined_at: Time.current)

    @member_a = User.create!(username: "member_a", email: "member_a@example.com", password: "password123")
    EmploymentDetail.create!(user: @member_a, team: @team_a, role: :member, job_position: "Engineer", joined_at: Time.current)

    @member_b = User.create!(username: "member_b", email: "member_b@example.com", password: "password123")
    EmploymentDetail.create!(user: @member_b, team: @team_b, role: :member, job_position: "Engineer", joined_at: Time.current)

    @admin_token = login(@admin)
    @member_a_token = login(@member_a)
    @member_b_token = login(@member_b)

    @project_a = Project.create!(title: "Project A", team: @team_a, created_by: @admin)
    @unassigned_project = Project.create!(title: "Unassigned", created_by: @admin)
  end

  test "admin can create a project; created_by is always the current admin" do
    post "/projects", params: { title: "New Project", created_by_id: @member_a.id },
                       headers: auth_headers(@admin_token)
    assert_response :created
    body = JSON.parse(response.body)
    assert_equal @admin.id, body["created_by_id"]
    assert_equal "planning", body["status"]
    assert_nil body["team_id"]
  end

  test "member cannot create a project" do
    post "/projects", params: { title: "New Project" }, headers: auth_headers(@member_a_token)
    assert_response :forbidden
  end

  test "admin sees all projects, including unassigned ones" do
    get "/projects", headers: auth_headers(@admin_token)
    assert_response :ok
    ids = JSON.parse(response.body).map { |p| p["id"] }
    assert_includes ids, @project_a.id
    assert_includes ids, @unassigned_project.id
  end

  test "team member sees only their own team's projects, not other teams' or unassigned ones" do
    get "/projects", headers: auth_headers(@member_a_token)
    assert_response :ok
    ids = JSON.parse(response.body).map { |p| p["id"] }
    assert_equal [@project_a.id], ids
  end

  test "member of a different team cannot view another team's project" do
    get "/projects/#{@project_a.id}", headers: auth_headers(@member_b_token)
    assert_response :forbidden
  end

  test "non-admin cannot view an unassigned project" do
    get "/projects/#{@unassigned_project.id}", headers: auth_headers(@member_a_token)
    assert_response :forbidden
  end

  test "regular update cannot change team_id" do
    patch "/projects/#{@project_a.id}", params: { team_id: @team_b.id }, headers: auth_headers(@admin_token)
    assert_response :ok
    assert_equal @team_a.id, @project_a.reload.team_id
  end

  test "status cannot be set to active without a team" do
    patch "/projects/#{@unassigned_project.id}", params: { status: "active" }, headers: auth_headers(@admin_token)
    assert_response :unprocessable_entity
  end

  test "end_date must be after start_date" do
    patch "/projects/#{@project_a.id}", params: { status: "active" }, headers: auth_headers(@admin_token)
    assert_response :ok
    start_date = JSON.parse(response.body)["start_date"]

    patch "/projects/#{@project_a.id}",
      params: { end_date: Date.parse(start_date).to_s },
      headers: auth_headers(@admin_token)
    assert_response :unprocessable_entity
  end

  test "activating a project sets start_date once" do
    patch "/projects/#{@project_a.id}", params: { status: "active" }, headers: auth_headers(@admin_token)
    assert_response :ok
    first_start_date = JSON.parse(response.body)["start_date"]
    assert_not_nil first_start_date

    patch "/projects/#{@project_a.id}", params: { status: "onhold" }, headers: auth_headers(@admin_token)
    patch "/projects/#{@project_a.id}", params: { status: "active" }, headers: auth_headers(@admin_token)
    assert_equal first_start_date, JSON.parse(response.body)["start_date"]
  end

  test "unassign_team archives the project" do
    delete "/projects/#{@project_a.id}/unassign_team", headers: auth_headers(@admin_token)
    assert_response :ok
    body = JSON.parse(response.body)
    assert_nil body["team_id"]
    assert_equal "archived", body["status"]
  end

  test "assign_team on an archived project leaves it archived" do
    delete "/projects/#{@project_a.id}/unassign_team", headers: auth_headers(@admin_token)
    post "/projects/#{@project_a.id}/assign_team", params: { team_name: @team_b.name }, headers: auth_headers(@admin_token)
    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal @team_b.id, body["team_id"]
    assert_equal "archived", body["status"]
  end

  test "assign_team matches the team name case-insensitively" do
    post "/projects/#{@project_a.id}/assign_team", params: { team_name: @team_b.name.upcase }, headers: auth_headers(@admin_token)
    assert_response :ok
    assert_equal @team_b.id, JSON.parse(response.body)["team_id"]
  end

  test "assign_team with an unknown team name is 404" do
    post "/projects/#{@project_a.id}/assign_team", params: { team_name: "Nonexistent" }, headers: auth_headers(@admin_token)
    assert_response :not_found
  end

  test "member cannot assign or unassign a team" do
    post "/projects/#{@project_a.id}/assign_team", params: { team_name: @team_b.name }, headers: auth_headers(@member_a_token)
    assert_response :forbidden

    delete "/projects/#{@project_a.id}/unassign_team", headers: auth_headers(@member_a_token)
    assert_response :forbidden
  end

  test "title and description length limits are enforced as 422, not a database error" do
    post "/projects", params: { title: "a" * 256 }, headers: auth_headers(@admin_token)
    assert_response :unprocessable_entity

    post "/projects", params: { title: "Too wordy", description: "b" * 5001 },
                       headers: auth_headers(@admin_token)
    assert_response :unprocessable_entity
  end

  test "admin can delete a project" do
    delete "/projects/#{@project_a.id}", headers: auth_headers(@admin_token)
    assert_response :no_content
  end

  private

  def login(user)
    post "/auth/login", params: { login: user.username, password: "password123" }
    JSON.parse(response.body)["access_token"]
  end

  def auth_headers(token)
    { "Authorization" => "Bearer #{token}" }
  end
end
