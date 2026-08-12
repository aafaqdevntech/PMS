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

  # --- index: admin only / show: any authenticated user ---

  test "admin can list all teams with the lead's name resolved" do
    lead = User.create!(username: "lead", email: "lead@example.com", password: "password123")
    Profile.create!(user: lead, full_name: "Lea Derson")
    EmploymentDetail.create!(user: lead, team: @team, role: :team_lead, job_position: "Lead", joined_at: Time.current)
    @team.update!(team_lead: lead)

    leadless = Team.create!(name: "Sales")

    get "/teams", headers: auth_headers(@admin_token)
    assert_response :ok
    body = JSON.parse(response.body)

    row = body.find { |t| t["id"] == @team.id }
    assert_equal %w[created_at description id name team_lead_id team_lead_name], row.keys.sort
    assert_equal lead.id, row["team_lead_id"]
    assert_equal "Lea Derson", row["team_lead_name"]

    leadless_row = body.find { |t| t["id"] == leadless.id }
    assert_nil leadless_row["team_lead_id"]
    assert_nil leadless_row["team_lead_name"]
  end

  test "a team lead with no profile gets a null team_lead_name" do
    lead = User.create!(username: "nolprofile_lead", email: "nolprofile_lead@example.com", password: "password123")
    EmploymentDetail.create!(user: lead, team: @team, role: :team_lead, job_position: "Lead", joined_at: Time.current)
    @team.update!(team_lead: lead)

    get "/teams", headers: auth_headers(@admin_token)
    assert_response :ok
    row = JSON.parse(response.body).find { |t| t["id"] == @team.id }
    assert_equal lead.id, row["team_lead_id"]
    assert_nil row["team_lead_name"]
  end

  test "a member cannot list all teams" do
    get "/teams", headers: auth_headers(@member_token)
    assert_response :forbidden
  end

  test "any authenticated user can view a single team, including teams they don't belong to" do
    other_team = Team.create!(name: "Sales")

    get "/teams/#{other_team.id}", headers: auth_headers(@member_token)
    assert_response :ok
  end

  test "show returns the same trimmed shape as index, with the lead's name resolved" do
    lead = User.create!(username: "showlead", email: "showlead@example.com", password: "password123")
    Profile.create!(user: lead, full_name: "Lea Derson")
    EmploymentDetail.create!(user: lead, team: @team, role: :team_lead, job_position: "Lead", joined_at: Time.current)
    @team.update!(team_lead: lead)

    get "/teams/#{@team.id}", headers: auth_headers(@member_token)
    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal %w[created_at description id name team_lead_id team_lead_name], body.keys.sort
    assert_equal lead.id, body["team_lead_id"]
    assert_equal "Lea Derson", body["team_lead_name"]
  end

  test "show on a leadless team returns null team_lead_id and team_lead_name" do
    leadless = Team.create!(name: "Sales")

    get "/teams/#{leadless.id}", headers: auth_headers(@member_token)
    assert_response :ok
    body = JSON.parse(response.body)
    assert_nil body["team_lead_id"]
    assert_nil body["team_lead_name"]
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

  # --- assign_lead ---

  test "admin assigns a promoted user as the team's lead, by username, cascading their employment_detail.team_id" do
    other_team = Team.create!(name: "Sales")
    promoted = User.create!(username: "promoted", email: "promoted@example.com", password: "password123")
    EmploymentDetail.create!(user: promoted, team: other_team, role: :team_lead, job_position: "Lead", joined_at: Time.current)

    patch "/teams/assign_lead", params: { team_id: @team.id, username: promoted.username },
      headers: auth_headers(@admin_token)

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal promoted.id, body["team_lead_id"]
    assert_equal promoted.id, @team.reload.team_lead_id
    assert_equal @team.id, promoted.employment_detail.reload.team_id
  end

  test "admin unassigns a team's lead by omitting username, cascading their employment_detail.team_id to null" do
    lead = User.create!(username: "curlead", email: "curlead@example.com", password: "password123")
    EmploymentDetail.create!(user: lead, team: @team, role: :team_lead, job_position: "Lead", joined_at: Time.current)
    @team.update!(team_lead: lead)

    patch "/teams/assign_lead", params: { team_id: @team.id }, headers: auth_headers(@admin_token)

    assert_response :ok
    assert_nil JSON.parse(response.body)["team_lead_id"]
    assert_nil @team.reload.team_lead_id
    assert_nil lead.employment_detail.reload.team_id
  end

  test "admin unassigns a team's lead by sending a blank username, cascading their employment_detail.team_id to null" do
    lead = User.create!(username: "curlead2", email: "curlead2@example.com", password: "password123")
    EmploymentDetail.create!(user: lead, team: @team, role: :team_lead, job_position: "Lead", joined_at: Time.current)
    @team.update!(team_lead: lead)

    patch "/teams/assign_lead", params: { team_id: @team.id, username: "" }, headers: auth_headers(@admin_token)

    assert_response :ok
    assert_nil @team.reload.team_lead_id
    assert_nil lead.employment_detail.reload.team_id
  end

  test "unassigning when the team has no current lead is a no-op success" do
    patch "/teams/assign_lead", params: { team_id: @team.id }, headers: auth_headers(@admin_token)

    assert_response :ok
    assert_nil @team.reload.team_lead_id
  end

  test "assigning a user who isn't yet promoted to team_lead is rejected" do
    patch "/teams/assign_lead", params: { team_id: @team.id, username: @member.username },
      headers: auth_headers(@admin_token)

    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_includes body["errors"].join, "first"
    assert_nil @team.reload.team_lead_id
  end

  test "assigning an unknown username is a 404" do
    patch "/teams/assign_lead", params: { team_id: @team.id, username: "ghost" }, headers: auth_headers(@admin_token)
    assert_response :not_found
  end

  test "assigning a user with no employment detail at all is a 404" do
    bare = User.create!(username: "bare", email: "bare@example.com", password: "password123")

    patch "/teams/assign_lead", params: { team_id: @team.id, username: bare.username },
      headers: auth_headers(@admin_token)
    assert_response :not_found
  end

  test "assigning to an unknown or missing team_id is a 404" do
    promoted = User.create!(username: "promoted2", email: "promoted2@example.com", password: "password123")
    EmploymentDetail.create!(user: promoted, team: @team, role: :team_lead, job_position: "Lead", joined_at: Time.current)

    patch "/teams/assign_lead", params: { team_id: 999_999, username: promoted.username },
      headers: auth_headers(@admin_token)
    assert_response :not_found

    patch "/teams/assign_lead", params: { username: promoted.username }, headers: auth_headers(@admin_token)
    assert_response :not_found
  end

  test "assigning a lead who already leads a different team is rejected" do
    other_team = Team.create!(name: "Sales")
    promoted = User.create!(username: "doublelead", email: "doublelead@example.com", password: "password123")
    EmploymentDetail.create!(user: promoted, team: @team, role: :team_lead, job_position: "Lead", joined_at: Time.current)
    other_team.update!(team_lead: promoted)

    patch "/teams/assign_lead", params: { team_id: @team.id, username: promoted.username },
      headers: auth_headers(@admin_token)

    assert_response :unprocessable_entity
  end

  test "only an admin can assign or unassign a team's lead" do
    promoted = User.create!(username: "promoted3", email: "promoted3@example.com", password: "password123")
    EmploymentDetail.create!(user: promoted, team: @team, role: :team_lead, job_position: "Lead", joined_at: Time.current)

    patch "/teams/assign_lead", params: { team_id: @team.id, username: promoted.username },
      headers: auth_headers(@member_token)
    assert_response :forbidden
  end

  test "assign_lead requires authentication" do
    patch "/teams/assign_lead", params: { team_id: @team.id, username: "whoever" }
    assert_response :unauthorized
  end

  # --- assign_member ---

  test "admin adds a member-role user with no team to the team" do
    solo = User.create!(username: "solo", email: "solo@example.com", password: "password123")
    EmploymentDetail.create!(user: solo, role: :member, job_position: "QA", joined_at: Time.current)

    patch "/teams/assign_member", params: { team_id: @team.id, username: solo.username },
      headers: auth_headers(@admin_token)

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal @team.id, body["team_id"]
    assert_equal @team.id, solo.employment_detail.reload.team_id
  end

  test "admin reassigns a member-role user from a different team to this one" do
    other_team = Team.create!(name: "Sales")
    elsewhere = User.create!(username: "elsewhere", email: "elsewhere@example.com", password: "password123")
    EmploymentDetail.create!(user: elsewhere, team: other_team, role: :member, job_position: "QA", joined_at: Time.current)

    patch "/teams/assign_member", params: { team_id: @team.id, username: elsewhere.username },
      headers: auth_headers(@admin_token)

    assert_response :ok
    assert_equal @team.id, elsewhere.employment_detail.reload.team_id
  end

  test "assigning a non-member-role user (team_lead or admin) as a member is rejected" do
    lead = User.create!(username: "leadrole", email: "leadrole@example.com", password: "password123")
    EmploymentDetail.create!(user: lead, team: @team, role: :team_lead, job_position: "Lead", joined_at: Time.current)

    patch "/teams/assign_member", params: { team_id: @team.id, username: lead.username },
      headers: auth_headers(@admin_token)

    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_includes body["errors"].join, "member"

    patch "/teams/assign_member", params: { team_id: @team.id, username: @admin.username },
      headers: auth_headers(@admin_token)
    assert_response :unprocessable_entity
  end

  test "assign_member with an unknown username or team_id is a 404" do
    patch "/teams/assign_member", params: { team_id: @team.id, username: "ghost" },
      headers: auth_headers(@admin_token)
    assert_response :not_found

    patch "/teams/assign_member", params: { team_id: 999_999, username: @member.username },
      headers: auth_headers(@admin_token)
    assert_response :not_found
  end

  test "assign_member for a user with no employment detail at all is a 404" do
    bare = User.create!(username: "baremember", email: "baremember@example.com", password: "password123")

    patch "/teams/assign_member", params: { team_id: @team.id, username: bare.username },
      headers: auth_headers(@admin_token)
    assert_response :not_found
  end

  test "only an admin can assign a member" do
    solo = User.create!(username: "solo2", email: "solo2@example.com", password: "password123")
    EmploymentDetail.create!(user: solo, role: :member, job_position: "QA", joined_at: Time.current)

    patch "/teams/assign_member", params: { team_id: @team.id, username: solo.username },
      headers: auth_headers(@member_token)
    assert_response :forbidden
  end

  test "assign_member requires authentication" do
    patch "/teams/assign_member", params: { team_id: @team.id, username: "whoever" }
    assert_response :unauthorized
  end

  # --- unassign_member ---

  test "admin removes a member from the team they belong to" do
    patch "/teams/unassign_member", params: { team_id: @team.id, username: @member.username },
      headers: auth_headers(@admin_token)

    assert_response :ok
    assert_nil JSON.parse(response.body)["team_id"]
    assert_nil @member.employment_detail.reload.team_id
  end

  test "unassigning a user from a team they don't belong to is rejected" do
    other_team = Team.create!(name: "Sales")

    patch "/teams/unassign_member", params: { team_id: other_team.id, username: @member.username },
      headers: auth_headers(@admin_token)

    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_includes body["errors"].join, "not a member"
    assert_equal @team.id, @member.employment_detail.reload.team_id
  end

  test "unassign_member with an unknown username or team_id is a 404" do
    patch "/teams/unassign_member", params: { team_id: @team.id, username: "ghost" },
      headers: auth_headers(@admin_token)
    assert_response :not_found

    patch "/teams/unassign_member", params: { team_id: 999_999, username: @member.username },
      headers: auth_headers(@admin_token)
    assert_response :not_found
  end

  test "only an admin can unassign a member" do
    patch "/teams/unassign_member", params: { team_id: @team.id, username: @member.username },
      headers: auth_headers(@member_token)
    assert_response :forbidden
  end

  test "unassign_member requires authentication" do
    patch "/teams/unassign_member", params: { team_id: @team.id, username: @member.username }
    assert_response :unauthorized
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
