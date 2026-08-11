require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @team = Team.create!(name: "Engineering")
    @admin = User.create!(username: "admin", email: "admin@example.com", password: "password123")
    EmploymentDetail.create!(user: @admin, role: :admin, job_position: "Admin", joined_at: Time.current)

    @member = User.create!(username: "member", email: "member@example.com", password: "password123")
    EmploymentDetail.create!(user: @member, team: @team, role: :member, job_position: "Engineer", joined_at: Time.current)

    @admin_token = login(@admin)
    @member_token = login(@member)
  end

  test "admin can list every user with the directory shape" do
    get "/users", headers: auth_headers(@admin_token)
    assert_response :ok
    body = JSON.parse(response.body)
    ids = body.map { |u| u["id"] }
    assert_includes ids, @admin.id
    assert_includes ids, @member.id

    admin_row = body.find { |u| u["id"] == @admin.id }
    assert_equal %w[email id image_url job_position joined_at role team_name username], admin_row.keys.sort
    assert_equal "admin", admin_row["role"]
    assert_equal "Admin", admin_row["job_position"]
    assert_equal "No record!", admin_row["team_name"], "admin has no team"
    assert_equal "No record!", admin_row["image_url"], "admin has no profile"
  end

  test "member with a team can list their team roster with the directory shape" do
    get "/users", headers: auth_headers(@member_token)
    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal [@member.id], body.map { |u| u["id"] }

    row = body.first
    assert_equal %w[email id image_url job_position joined_at role team_name username], row.keys.sort
    assert_equal "member", row["role"]
    assert_equal "Engineering", row["team_name"]
    assert_equal "Engineer", row["job_position"]
    assert_equal "No record!", row["image_url"], "member has no profile"
    assert_not_equal "No record!", row["joined_at"]
  end

  test "a user with no profile gets \"No record!\" for image_url only" do
    no_profile = User.create!(username: "no_profile", email: "no_profile@example.com", password: "password123")
    EmploymentDetail.create!(user: no_profile, team: @team, role: :member, job_position: "QA", joined_at: Time.current)

    get "/users", headers: auth_headers(@admin_token)
    assert_response :ok
    row = JSON.parse(response.body).find { |u| u["id"] == no_profile.id }
    assert_equal "No record!", row["image_url"]
    assert_equal "member", row["role"]
    assert_equal "Engineering", row["team_name"]
    assert_equal "QA", row["job_position"]
  end

  test "a user with no employment detail gets \"No record!\" for role, team_name, job_position, and joined_at" do
    bare = User.create!(username: "bare", email: "bare@example.com", password: "password123")

    get "/users", headers: auth_headers(@admin_token)
    assert_response :ok
    row = JSON.parse(response.body).find { |u| u["id"] == bare.id }
    assert_equal "bare", row["username"]
    assert_equal "No record!", row["role"]
    assert_equal "No record!", row["team_name"]
    assert_equal "No record!", row["job_position"]
    assert_equal "No record!", row["joined_at"]
    assert_equal "No record!", row["image_url"], "no profile either"
  end

  test "member with no team cannot list users" do
    solo = User.create!(username: "solo", email: "solo@example.com", password: "password123")
    EmploymentDetail.create!(user: solo, role: :member, job_position: "Freelancer", joined_at: Time.current)

    get "/users", headers: auth_headers(login(solo))
    assert_response :forbidden
  end

  test "member can view their own record with full fields" do
    get "/users/#{@member.id}", headers: auth_headers(@member_token)
    assert_response :ok
    body = JSON.parse(response.body)
    assert body.key?("created_at")
  end

  test "member cannot view an unrelated user's record" do
    get "/users/#{@admin.id}", headers: auth_headers(@member_token)
    assert_response :forbidden
  end

  test "member can view a teammate's record with limited fields" do
    teammate = User.create!(username: "teammate", email: "teammate@example.com", password: "password123")
    EmploymentDetail.create!(user: teammate, team: @team, role: :member, job_position: "Designer", joined_at: Time.current)

    get "/users/#{teammate.id}", headers: auth_headers(@member_token)
    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal %w[email full_name id image_url job_position role username], body.keys.sort
  end

  test "the full UserSerializer never leaks password_digest or the reset token" do
    get "/users/#{@member.id}", headers: auth_headers(@member_token)
    assert_response :ok
    body = JSON.parse(response.body)
    assert_not body.key?("password_digest")
    assert_not body.key?("reset_password_token")
    assert_not body.key?("reset_password_sent_at")
  end

  test "admin can create a user" do
    post "/users", params: { username: "new", email: "new@example.com", password: "password123" },
                    headers: auth_headers(@admin_token)
    assert_response :created
  end

  test "member cannot create a user" do
    post "/users", params: { username: "new", email: "new@example.com", password: "password123" },
                    headers: auth_headers(@member_token)
    assert_response :forbidden
  end

  test "requests without a token are unauthorized" do
    get "/users"
    assert_response :unauthorized
  end

  # --- update ---

  test "admin can update a user's username and email" do
    patch "/users/#{@member.id}", params: { username: "renamed", email: "renamed@example.com" },
                                   headers: auth_headers(@admin_token)
    assert_response :ok
    @member.reload
    assert_equal "renamed", @member.username
    assert_equal "renamed@example.com", @member.email
  end

  test "admin can update a user's password" do
    patch "/users/#{@member.id}", params: { password: "newpassword1", password_confirmation: "newpassword1" },
                                   headers: auth_headers(@admin_token)
    assert_response :ok
    assert @member.reload.authenticate("newpassword1")
  end

  test "a non-admin cannot update any user, not even their own record" do
    patch "/users/#{@member.id}", params: { username: "self-renamed" }, headers: auth_headers(@member_token)
    assert_response :forbidden
    assert_equal "member", @member.reload.username
  end

  test "update enforces email uniqueness and format" do
    patch "/users/#{@member.id}", params: { email: @admin.email }, headers: auth_headers(@admin_token)
    assert_response :unprocessable_entity

    patch "/users/#{@member.id}", params: { email: "not-an-email" }, headers: auth_headers(@admin_token)
    assert_response :unprocessable_entity
  end

  # --- destroy ---

  test "admin can delete a user" do
    delete "/users/#{@member.id}", headers: auth_headers(@admin_token)
    assert_response :no_content
    assert_nil User.find_by(id: @member.id)
  end

  test "a non-admin cannot delete any user" do
    delete "/users/#{@member.id}", headers: auth_headers(@member_token)
    assert_response :forbidden
    assert User.exists?(@member.id)
  end

  test "deleting a user who still has created_tasks is blocked" do
    lead = User.create!(username: "lead", email: "lead@example.com", password: "password123")
    EmploymentDetail.create!(user: lead, team: @team, role: :team_lead, job_position: "Lead", joined_at: Time.current)
    @team.update!(team_lead: lead)

    project = Project.create!(title: "P", team: @team, created_by: @admin, status: :active)
    Task.create!(title: "T", description: "d", project: project, created_by: lead)

    delete "/users/#{lead.id}", headers: auth_headers(@admin_token)
    assert_response :unprocessable_entity
    assert User.exists?(lead.id)
  end

  test "deleting a user who raised an issue is blocked with a clean 422" do
    project = Project.create!(title: "P", team: @team, created_by: @admin, status: :active)
    Issue.create!(title: "Bug", project: project, raised_by: @member)

    delete "/users/#{@member.id}", headers: auth_headers(@admin_token)
    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_includes body["errors"].join, "raised issues"
    assert User.exists?(@member.id)
  end

  # --- /me ---

  test "GET /me returns the current user's own record" do
    get "/me", headers: auth_headers(@member_token)
    assert_response :ok
    assert_equal @member.id, JSON.parse(response.body)["id"]
  end

  # --- /me/counts ---

  test "GET /me/counts requires authentication" do
    get "/me/counts"
    assert_response :unauthorized
  end

  test "admin sees company-wide counts across teams, projects, tasks, and issues" do
    other_team = Team.create!(name: "Design")
    lead = User.create!(username: "lead1", email: "lead1@example.com", password: "password123")
    EmploymentDetail.create!(user: lead, team: @team, role: :team_lead, job_position: "Lead", joined_at: Time.current)
    @team.update!(team_lead: lead)

    project = Project.create!(title: "P1", team: @team, created_by: @admin, status: :active)
    Project.create!(title: "P2", team: other_team, created_by: @admin, status: :active)
    Task.create!(title: "T1", description: "d", project: project, created_by: lead)
    Issue.create!(title: "Bug", project: project, raised_by: @member)

    get "/me/counts", headers: auth_headers(@admin_token)
    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal "admin", body["role"]
    assert_equal Team.count, body["counts"]["teams"]
    assert_equal Project.count, body["counts"]["projects"]
    assert_equal Task.count, body["counts"]["tasks"]
    assert_equal Issue.count, body["counts"]["issues"]
  end

  test "team lead sees counts scoped to the team they actually lead" do
    other_team = Team.create!(name: "Design")

    lead = User.create!(username: "lead2", email: "lead2@example.com", password: "password123")
    EmploymentDetail.create!(user: lead, team: @team, role: :team_lead, job_position: "Lead", joined_at: Time.current)
    @team.update!(team_lead: lead)

    project = Project.create!(title: "In team", team: @team, created_by: @admin, status: :active)
    Task.create!(title: "T", description: "d", project: project, created_by: lead)
    Issue.create!(title: "Bug", project: project, raised_by: @member)

    other_lead = User.create!(username: "other_lead", email: "other_lead@example.com", password: "password123")
    EmploymentDetail.create!(user: other_lead, team: other_team, role: :team_lead,
                             job_position: "Lead", joined_at: Time.current)
    other_team.update!(team_lead: other_lead)
    other_project = Project.create!(title: "Other team", team: other_team, created_by: @admin, status: :active)
    Task.create!(title: "Elsewhere", description: "d", project: other_project, created_by: other_lead)
    Issue.create!(title: "Elsewhere bug", project: other_project, raised_by: other_lead)

    get "/me/counts", headers: auth_headers(login(lead))
    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal "team_lead", body["role"]
    assert_equal 1, body["counts"]["projects"]
    assert_equal 1, body["counts"]["tasks"]
    assert_equal 1, body["counts"]["issues"]
    assert_equal EmploymentDetail.where(team_id: @team.id).count, body["counts"]["team_members"]
  end

  test "a role of team_lead without being the team's designated lead gets member-scoped counts of zero" do
    fake_lead = User.create!(username: "fake_lead", email: "fake_lead@example.com", password: "password123")
    EmploymentDetail.create!(user: fake_lead, team: @team, role: :team_lead,
                             job_position: "Lead", joined_at: Time.current)

    get "/me/counts", headers: auth_headers(login(fake_lead))
    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal "member", body["role"]
    assert_equal({ "projects" => Project.where(team_id: @team.id).count, "my_tasks" => 0, "issues" => 0,
                   "due_today_tasks" => 0,
                   "team_members" => EmploymentDetail.where(team_id: @team.id).count }, body["counts"])
  end

  test "member sees their own assigned tasks, raised issues, tasks due today, projects, and team headcount" do
    lead = User.create!(username: "lead3", email: "lead3@example.com", password: "password123")
    EmploymentDetail.create!(user: lead, team: @team, role: :team_lead, job_position: "Lead", joined_at: Time.current)
    @team.update!(team_lead: lead)

    project = Project.create!(title: "P", team: @team, created_by: @admin, status: :active)

    due_today = Task.create!(title: "Due today", description: "d", project: project, created_by: lead)
    due_today.update!(assigned_to: @member, status: :assigned, due_date: Date.current)

    due_later = Task.create!(title: "Due later", description: "d", project: project, created_by: lead)
    due_later.update!(assigned_to: @member, status: :assigned, due_date: Date.current + 3)

    Task.create!(title: "Not mine", description: "d", project: project, created_by: lead)

    Issue.create!(title: "Reported", project: project, raised_by: @member)

    get "/me/counts", headers: auth_headers(@member_token)
    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal "member", body["role"]
    assert_equal Project.where(team_id: @team.id).count, body["counts"]["projects"]
    assert_equal 2, body["counts"]["my_tasks"]
    assert_equal 1, body["counts"]["issues"]
    assert_equal 1, body["counts"]["due_today_tasks"]
    assert_equal EmploymentDetail.where(team_id: @team.id).count, body["counts"]["team_members"]
  end

  test "a member with no team, tasks, or issues gets all zero counts" do
    solo = User.create!(username: "solo_counts", email: "solo_counts@example.com", password: "password123")
    EmploymentDetail.create!(user: solo, role: :member, job_position: "Freelancer", joined_at: Time.current)

    get "/me/counts", headers: auth_headers(login(solo))
    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal "member", body["role"]
    assert_equal({ "projects" => 0, "my_tasks" => 0, "issues" => 0, "due_today_tasks" => 0, "team_members" => 0 },
                 body["counts"])
  end

  private

  def login(user)
    post "/auth/login", params: { username: user.username, password: "password123" }
    JSON.parse(response.body)["access_token"]
  end

  def auth_headers(token)
    { "Authorization" => "Bearer #{token}" }
  end
end
