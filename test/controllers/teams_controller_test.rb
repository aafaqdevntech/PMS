require "test_helper"

class TeamsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(username: "admin", email: "admin@example.com", password: "password123")
    EmploymentDetail.create!(user: @admin, role: :admin, job_position: "Admin", joined_at: Time.current)

    @team = Team.create!(name: "Engineering")
    @member = User.create!(username: "member", email: "member@example.com", password: "password123")
    EmploymentDetail.create!(user: @member, team: @team, role: :member, job_position: "Engineer", joined_at: Time.current)

    @admin_token = login(@admin)
    @member_token = login(@member)
  end

  # --- index / show: any authenticated user ---

  test "any authenticated user can list all teams" do
    Team.create!(name: "Sales")

    get "/teams", headers: auth_headers(@admin_token)
    assert_response :ok
    admin_ids = JSON.parse(response.body).map { |t| t["id"] }

    get "/teams", headers: auth_headers(@member_token)
    assert_response :ok
    member_ids = JSON.parse(response.body).map { |t| t["id"] }

    assert_equal admin_ids.sort, member_ids.sort
    assert_includes member_ids, @team.id
  end

  test "any authenticated user can view a single team, including teams they don't belong to" do
    other_team = Team.create!(name: "Sales")

    get "/teams/#{other_team.id}", headers: auth_headers(@member_token)
    assert_response :ok
  end

  test "requests without a token are unauthorized" do
    get "/teams"
    assert_response :unauthorized
  end

  # --- create ---

  test "admin can create a team" do
    post "/teams", params: { name: "Marketing", description: "Growth" }, headers: auth_headers(@admin_token)
    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "Marketing", body["name"]
  end

  test "member cannot create a team" do
    post "/teams", params: { name: "Marketing" }, headers: auth_headers(@member_token)
    assert_response :forbidden
  end

  test "team name must be present and unique, case-insensitively" do
    post "/teams", params: { name: "" }, headers: auth_headers(@admin_token)
    assert_response :unprocessable_entity

    post "/teams", params: { name: "engineering" }, headers: auth_headers(@admin_token)
    assert_response :unprocessable_entity
  end

  test "team_lead_id must be unique across teams" do
    @team.update!(team_lead: @member)

    post "/teams", params: { name: "Duplicate Lead", team_lead_id: @member.id }, headers: auth_headers(@admin_token)
    assert_response :unprocessable_entity
  end

  # --- update ---

  test "admin can update a team" do
    patch "/teams/#{@team.id}", params: { description: "Now with more engineers" }, headers: auth_headers(@admin_token)
    assert_response :ok
    assert_equal "Now with more engineers", JSON.parse(response.body)["description"]
  end

  test "member cannot update a team" do
    patch "/teams/#{@team.id}", params: { name: "Hijacked" }, headers: auth_headers(@member_token)
    assert_response :forbidden
  end

  test "reassigning team_lead_id to someone who already leads another team is rejected" do
    other_team = Team.create!(name: "Sales", team_lead: @member)

    patch "/teams/#{@team.id}", params: { team_lead_id: @member.id }, headers: auth_headers(@admin_token)
    assert_response :unprocessable_entity
  end

  # --- destroy ---

  test "admin cannot delete a team that still has employment details" do
    delete "/teams/#{@team.id}", headers: auth_headers(@admin_token)

    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_includes body["errors"].join, "employment details"
  end

  test "admin cannot delete a team that still has projects" do
    empty_team = Team.create!(name: "Has Projects")
    Project.create!(title: "P", team: empty_team, created_by: @admin)

    delete "/teams/#{empty_team.id}", headers: auth_headers(@admin_token)

    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_includes body["errors"].join, "projects"
  end

  test "admin can delete a team with no dependents" do
    empty_team = Team.create!(name: "Empty")

    delete "/teams/#{empty_team.id}", headers: auth_headers(@admin_token)
    assert_response :no_content
    assert_nil Team.find_by(id: empty_team.id)
  end

  test "member cannot delete a team" do
    delete "/teams/#{@team.id}", headers: auth_headers(@member_token)
    assert_response :forbidden
    assert Team.exists?(@team.id)
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
