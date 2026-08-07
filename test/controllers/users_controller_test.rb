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

  private

  def login(user)
    post "/auth/login", params: { username: user.username, password: "password123" }
    JSON.parse(response.body)["access_token"]
  end

  def auth_headers(token)
    { "Authorization" => "Bearer #{token}" }
  end
end
