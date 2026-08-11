require "test_helper"

class EmploymentDetailsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @team = Team.create!(name: "Team A")

    @admin = User.create!(username: "admin", email: "admin@example.com", password: "password123")
    EmploymentDetail.create!(user: @admin, role: :admin, job_position: "Admin", joined_at: Time.current)

    @owner = User.create!(username: "owner", email: "owner@example.com", password: "password123")
    EmploymentDetail.create!(user: @owner, team: @team, role: :member, job_position: "Engineer", joined_at: Time.current)

    # no employment_detail at all
    @other = User.create!(username: "other", email: "other@example.com", password: "password123")

    @outsider = User.create!(username: "outsider", email: "outsider@example.com", password: "password123")
    EmploymentDetail.create!(user: @outsider, team: @team, role: :member, job_position: "Engineer", joined_at: Time.current)

    # has an employment_detail, but no team yet
    @unassigned = User.create!(username: "unassigned", email: "unassigned@example.com", password: "password123")
    EmploymentDetail.create!(user: @unassigned, role: :member, job_position: "QA", joined_at: Time.current)

    @admin_token = login(@admin)
    @owner_token = login(@owner)
    @outsider_token = login(@outsider)
  end

  # --- show ---

  test "the owner can view their own employment detail" do
    get "/users/#{@owner.id}/employment_detail", headers: auth_headers(@owner_token)
    assert_response :ok
    assert_equal "member", JSON.parse(response.body)["role"]
  end

  test "an admin can view anyone's employment detail" do
    get "/users/#{@owner.id}/employment_detail", headers: auth_headers(@admin_token)
    assert_response :ok
  end

  test "a non-owner, non-admin cannot view someone else's employment detail" do
    get "/users/#{@owner.id}/employment_detail", headers: auth_headers(@outsider_token)
    assert_response :forbidden
  end

  test "viewing an employment detail that was never created is a 404 for the owner" do
    get "/users/#{@other.id}/employment_detail", headers: auth_headers(login(@other))
    assert_response :not_found
  end

  test "a missing employment detail 404s even for a non-owner, before the forbidden check runs" do
    get "/users/#{@other.id}/employment_detail", headers: auth_headers(@outsider_token)
    assert_response :not_found
  end

  # --- create ---

  test "an admin can create an employment detail for a user" do
    post "/users/#{@other.id}/employment_detail",
      params: { team_id: @team.id, role: "member", job_position: "Designer", joined_at: Time.current },
      headers: auth_headers(@admin_token)
    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "member", body["role"]
    assert_equal @team.id, body["team_id"]
  end

  test "a non-admin cannot create an employment detail, even their own" do
    post "/users/#{@other.id}/employment_detail",
      params: { role: "member", job_position: "Designer", joined_at: Time.current },
      headers: auth_headers(login(@other))
    assert_response :forbidden
  end

  test "job_position and joined_at are required" do
    post "/users/#{@other.id}/employment_detail", params: { role: "member" }, headers: auth_headers(@admin_token)
    assert_response :unprocessable_entity
  end

  test "an admin role cannot be created together with a team" do
    post "/users/#{@other.id}/employment_detail",
      params: { team_id: @team.id, role: "admin", job_position: "Admin", joined_at: Time.current },
      headers: auth_headers(@admin_token)
    assert_response :unprocessable_entity
  end

  test "an admin role with no team is accepted" do
    post "/users/#{@other.id}/employment_detail",
      params: { role: "admin", job_position: "Admin", joined_at: Time.current },
      headers: auth_headers(@admin_token)
    assert_response :created
  end

  test "a user cannot have two employment details; the existing one is left untouched" do
    post "/users/#{@owner.id}/employment_detail",
      params: { role: "member", job_position: "Dup", joined_at: Time.current },
      headers: auth_headers(@admin_token)

    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_includes body["errors"].join, "Use PATCH"

    assert_equal "Engineer", @owner.reload.employment_detail.job_position
  end

  # --- update ---

  test "an admin can update an employment detail" do
    patch "/users/#{@owner.id}/employment_detail", params: { job_position: "Senior Engineer" },
      headers: auth_headers(@admin_token)
    assert_response :ok
    assert_equal "Senior Engineer", JSON.parse(response.body)["job_position"]
  end

  test "the owner cannot update their own employment detail" do
    patch "/users/#{@owner.id}/employment_detail", params: { job_position: "Senior Engineer" },
      headers: auth_headers(@owner_token)
    assert_response :forbidden
  end

  test "updating an employment detail that does not exist is a 404" do
    patch "/users/#{@other.id}/employment_detail", params: { job_position: "X" }, headers: auth_headers(@admin_token)
    assert_response :not_found
  end

  # --- destroy ---

  test "an admin can delete an employment detail" do
    delete "/users/#{@owner.id}/employment_detail", headers: auth_headers(@admin_token)
    assert_response :no_content
    assert_nil EmploymentDetail.find_by(user_id: @owner.id)
  end

  test "the owner cannot delete their own employment detail" do
    delete "/users/#{@owner.id}/employment_detail", headers: auth_headers(@owner_token)
    assert_response :forbidden
  end

  test "deleting an employment detail that does not exist is a 404" do
    delete "/users/#{@other.id}/employment_detail", headers: auth_headers(@admin_token)
    assert_response :not_found
  end

  # --- assign_team ---

  test "an admin can assign a team to a user with none" do
    patch "/users/#{@unassigned.id}/employment_detail/assign_team", params: { team_id: @team.id },
      headers: auth_headers(@admin_token)
    assert_response :ok
    assert_equal @team.id, JSON.parse(response.body)["team_id"]
    assert_equal @team.id, @unassigned.reload.employment_detail.team_id
  end

  test "an admin can unassign a team by sending a null team_id" do
    patch "/users/#{@owner.id}/employment_detail/assign_team", params: { team_id: nil },
      headers: auth_headers(@admin_token)
    assert_response :ok
    assert_nil JSON.parse(response.body)["team_id"]
    assert_nil @owner.reload.employment_detail.team_id
  end

  test "an admin can unassign a team by omitting team_id entirely" do
    patch "/users/#{@owner.id}/employment_detail/assign_team", headers: auth_headers(@admin_token)
    assert_response :ok
    assert_nil @owner.reload.employment_detail.team_id
  end

  test "an admin can reassign a user from one team to another" do
    other_team = Team.create!(name: "Team B")
    patch "/users/#{@owner.id}/employment_detail/assign_team", params: { team_id: other_team.id },
      headers: auth_headers(@admin_token)
    assert_response :ok
    assert_equal other_team.id, @owner.reload.employment_detail.team_id
  end

  test "assigning a team_id that doesn't exist in the database is a 404" do
    patch "/users/#{@owner.id}/employment_detail/assign_team", params: { team_id: 999_999 },
      headers: auth_headers(@admin_token)
    assert_response :not_found
    assert_equal @team.id, @owner.reload.employment_detail.team_id
  end

  test "only an admin can assign or unassign a team, not even the owner" do
    [@owner_token, @outsider_token].each do |token|
      patch "/users/#{@owner.id}/employment_detail/assign_team", params: { team_id: @team.id },
        headers: auth_headers(token)
      assert_response :forbidden
    end
  end

  test "assign_team on a user with no employment detail at all is a 404" do
    patch "/users/#{@other.id}/employment_detail/assign_team", params: { team_id: @team.id },
      headers: auth_headers(@admin_token)
    assert_response :not_found
  end

  test "assigning a team to an admin's employment detail is rejected" do
    patch "/users/#{@admin.id}/employment_detail/assign_team", params: { team_id: @team.id },
      headers: auth_headers(@admin_token)
    assert_response :unprocessable_entity
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
