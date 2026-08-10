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

  test "admin can list users" do
    get "/users", headers: auth_headers(@admin_token)
    assert_response :ok
  end

  test "member with a team can list their team roster with limited fields" do
    get "/users", headers: auth_headers(@member_token)
    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal [@member.id], body.map { |u| u["id"] }
    assert_equal %w[email full_name id image_url job_position role username], body.first.keys.sort
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

  private

  def login(user)
    post "/auth/login", params: { username: user.username, password: "password123" }
    JSON.parse(response.body)["access_token"]
  end

  def auth_headers(token)
    { "Authorization" => "Bearer #{token}" }
  end
end
