require "test_helper"

class IssuesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @team = Team.create!(name: "Team A")
    @other_team = Team.create!(name: "Team B")

    @admin = User.create!(username: "admin", email: "admin@example.com", password: "password123")
    EmploymentDetail.create!(user: @admin, role: :admin, job_position: "Admin", joined_at: Time.current)

    @lead = User.create!(username: "lead", email: "lead@example.com", password: "password123")
    EmploymentDetail.create!(user: @lead, team: @team, role: :team_lead, job_position: "Lead", joined_at: Time.current)
    @team.update!(team_lead: @lead)

    @owner = User.create!(username: "owner", email: "owner@example.com", password: "password123")
    EmploymentDetail.create!(user: @owner, team: @team, role: :member, job_position: "Engineer", joined_at: Time.current)

    @teammate = User.create!(username: "teammate", email: "teammate@example.com", password: "password123")
    EmploymentDetail.create!(user: @teammate, team: @team, role: :member, job_position: "Engineer", joined_at: Time.current)

    # role: team_lead, but NOT teams.team_lead_id — must have no special power.
    @fake_lead = User.create!(username: "fake_lead", email: "fake_lead@example.com", password: "password123")
    EmploymentDetail.create!(user: @fake_lead, team: @team, role: :team_lead, job_position: "Lead", joined_at: Time.current)

    @outsider = User.create!(username: "outsider", email: "outsider@example.com", password: "password123")
    EmploymentDetail.create!(user: @outsider, team: @other_team, role: :member, job_position: "Engineer", joined_at: Time.current)

    @project = Project.create!(title: "Project A", team: @team, created_by: @admin, status: :active)
    @other_project = Project.create!(title: "Project B", team: @other_team, created_by: @admin, status: :active)

    @issue = Issue.create!(title: "Bug", description: "It breaks", project: @project, raised_by: @owner)

    @admin_token = login(@admin)
    @lead_token = login(@lead)
    @owner_token = login(@owner)
    @teammate_token = login(@teammate)
    @fake_lead_token = login(@fake_lead)
    @outsider_token = login(@outsider)
  end

  # --- creating ---

  test "team member raises an issue; raised_by is forced to current user and status starts open" do
    post "/projects/#{@project.id}/issues",
      params: { title: "New bug", description: "details", raised_by_id: @teammate.id, status: "resolved" },
      headers: auth_headers(@owner_token)

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal @owner.id, body["raised_by_id"]
    assert_equal "open", body["status"]
    assert_nil body["resolution_note"]
  end

  test "team lead can also raise an issue" do
    post "/projects/#{@project.id}/issues", params: { title: "Lead bug" }, headers: auth_headers(@lead_token)
    assert_response :created
  end

  test "admin cannot raise an issue" do
    post "/projects/#{@project.id}/issues", params: { title: "Admin bug" }, headers: auth_headers(@admin_token)
    assert_response :forbidden
  end

  test "member of another team cannot raise an issue on this project" do
    post "/projects/#{@project.id}/issues", params: { title: "Nope" }, headers: auth_headers(@outsider_token)
    assert_response :forbidden
  end

  test "cannot raise an issue on a project that is not active" do
    planning = Project.create!(title: "Planning", team: @team, created_by: @admin)
    post "/projects/#{planning.id}/issues", params: { title: "Too early" }, headers: auth_headers(@owner_token)
    assert_response :unprocessable_entity
  end

  test "title and description length limits are enforced as 422, not a database error" do
    post "/projects/#{@project.id}/issues", params: { title: "a" * 256 }, headers: auth_headers(@owner_token)
    assert_response :unprocessable_entity

    post "/projects/#{@project.id}/issues",
      params: { title: "Too wordy", description: "b" * 5001 }, headers: auth_headers(@owner_token)
    assert_response :unprocessable_entity
  end

  test "a resolution note longer than the limit is rejected" do
    post "/issues/#{@issue.id}/resolve", params: { resolution_note: "c" * 5001 }, headers: auth_headers(@lead_token)
    assert_response :unprocessable_entity
    assert_equal "open", @issue.reload.status
  end

  # --- reading ---

  test "teammates and admin can read issues; other teams cannot" do
    get "/issues/#{@issue.id}", headers: auth_headers(@teammate_token)
    assert_response :ok

    get "/issues/#{@issue.id}", headers: auth_headers(@admin_token)
    assert_response :ok

    get "/issues/#{@issue.id}", headers: auth_headers(@outsider_token)
    assert_response :forbidden
  end

  test "index lists only the project's issues and is blocked for other teams" do
    get "/projects/#{@project.id}/issues", headers: auth_headers(@owner_token)
    assert_response :ok
    assert_equal [@issue.id], JSON.parse(response.body).map { |i| i["id"] }

    get "/projects/#{@project.id}/issues", headers: auth_headers(@outsider_token)
    assert_response :forbidden
  end

  # --- updating ---

  test "owner can edit their own open issue" do
    patch "/issues/#{@issue.id}", params: { title: "Edited" }, headers: auth_headers(@owner_token)
    assert_response :ok
    assert_equal "Edited", @issue.reload.title
  end

  test "owner cannot change status or resolution_note through update" do
    patch "/issues/#{@issue.id}",
      params: { status: "resolved", resolution_note: "sneaky" },
      headers: auth_headers(@owner_token)

    assert_response :ok
    @issue.reload
    assert_equal "open", @issue.status
    assert_nil @issue.resolution_note
  end

  test "nobody but the owner can edit an issue" do
    [@teammate_token, @lead_token, @admin_token].each do |token|
      patch "/issues/#{@issue.id}", params: { title: "Hijack" }, headers: auth_headers(token)
      assert_response :forbidden
    end
  end

  test "a non-owner teammate or lead cannot delete an issue" do
    [@teammate_token, @lead_token].each do |token|
      delete "/issues/#{@issue.id}", headers: auth_headers(token)
      assert_response :forbidden
    end
    assert Issue.exists?(@issue.id)
  end

  test "owner can delete their own open issue" do
    delete "/issues/#{@issue.id}", headers: auth_headers(@owner_token)
    assert_response :no_content
  end

  test "an admin can delete any open issue, on any team" do
    other = Issue.create!(title: "Theirs", description: "Other team", project: @other_project,
                          raised_by: @outsider)

    delete "/issues/#{@issue.id}", headers: auth_headers(@admin_token)
    assert_response :no_content

    delete "/issues/#{other.id}", headers: auth_headers(@admin_token)
    assert_response :no_content
  end

  # --- resolving / rejecting ---

  test "team lead resolves an issue with a resolution note" do
    post "/issues/#{@issue.id}/resolve", params: { resolution_note: "Fixed in v2" }, headers: auth_headers(@lead_token)
    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal "resolved", body["status"]
    assert_equal "Fixed in v2", body["resolution_note"]
  end

  test "team lead rejects an issue with a resolution note" do
    post "/issues/#{@issue.id}/reject", params: { resolution_note: "Not a bug" }, headers: auth_headers(@lead_token)
    assert_response :ok
    assert_equal "rejected", JSON.parse(response.body)["status"]
  end

  test "resolving without a resolution note is rejected" do
    post "/issues/#{@issue.id}/resolve", headers: auth_headers(@lead_token)
    assert_response :unprocessable_entity
    assert_equal "open", @issue.reload.status
  end

  test "only the team's designated lead can resolve - not owner, teammate, admin, or a role-only team_lead" do
    [@owner_token, @teammate_token, @admin_token, @fake_lead_token, @outsider_token].each do |token|
      post "/issues/#{@issue.id}/resolve", params: { resolution_note: "nope" }, headers: auth_headers(token)
      assert_response :forbidden
    end
    assert_equal "open", @issue.reload.status
  end

  # --- terminal lock ---

  test "a resolved issue is locked for the team that raised it" do
    post "/issues/#{@issue.id}/resolve", params: { resolution_note: "Fixed" }, headers: auth_headers(@lead_token)
    assert_response :ok

    patch "/issues/#{@issue.id}", params: { title: "Edited" }, headers: auth_headers(@owner_token)
    assert_response :forbidden

    delete "/issues/#{@issue.id}", headers: auth_headers(@owner_token)
    assert_response :forbidden

    post "/issues/#{@issue.id}/resolve", params: { resolution_note: "Again" }, headers: auth_headers(@lead_token)
    assert_response :forbidden

    post "/issues/#{@issue.id}/reject", params: { resolution_note: "Flip it" }, headers: auth_headers(@lead_token)
    assert_response :forbidden

    @issue.reload
    assert_equal "resolved", @issue.status
    assert_equal "Fixed", @issue.resolution_note
  end

  test "an admin can delete a closed issue, which nobody else can" do
    rejected = Issue.create!(title: "Wontfix", description: "No", project: @project, raised_by: @owner)

    post "/issues/#{@issue.id}/resolve", params: { resolution_note: "Fixed" }, headers: auth_headers(@lead_token)
    assert_response :ok
    post "/issues/#{rejected.id}/reject", params: { resolution_note: "Out of scope" },
      headers: auth_headers(@lead_token)
    assert_response :ok

    # The raiser and the lead are still locked out of both.
    [@owner_token, @lead_token].each do |token|
      delete "/issues/#{@issue.id}", headers: auth_headers(token)
      assert_response :forbidden
    end

    delete "/issues/#{@issue.id}", headers: auth_headers(@admin_token)
    assert_response :no_content

    delete "/issues/#{rejected.id}", headers: auth_headers(@admin_token)
    assert_response :no_content

    assert_nil Issue.find_by(id: @issue.id)
    assert_nil Issue.find_by(id: rejected.id)
  end

  test "an admin deleting a closed issue leaves its tasks behind, unlinked" do
    task = Task.create!(title: "Promoted", description: "From the issue", project: @project,
                        created_by: @lead, issue: @issue)
    post "/issues/#{@issue.id}/resolve", params: { resolution_note: "Fixed" }, headers: auth_headers(@lead_token)

    delete "/issues/#{@issue.id}", headers: auth_headers(@admin_token)
    assert_response :no_content

    assert task.reload.persisted?
    assert_nil task.issue_id
  end

  test "a resolved issue is still readable by teammates and admin" do
    post "/issues/#{@issue.id}/resolve", params: { resolution_note: "Fixed" }, headers: auth_headers(@lead_token)

    get "/issues/#{@issue.id}", headers: auth_headers(@teammate_token)
    assert_response :ok

    get "/issues/#{@issue.id}", headers: auth_headers(@admin_token)
    assert_response :ok
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
