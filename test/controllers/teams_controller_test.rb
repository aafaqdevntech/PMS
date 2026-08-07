require "test_helper"

class TeamsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(username: "admin", email: "admin@example.com", password: "password123")
    EmploymentDetail.create!(user: @admin, role: :admin, job_position: "Admin", joined_at: Time.current)
    @admin_token = login(@admin)
  end

  test "admin cannot delete a team that still has employment details" do
    team = Team.create!(name: "Engineering")
    member = User.create!(username: "member", email: "member@example.com", password: "password123")
    EmploymentDetail.create!(user: member, team: team, role: :member, job_position: "Engineer", joined_at: Time.current)

    delete "/teams/#{team.id}", headers: auth_headers(@admin_token)

    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_includes body["errors"].join, "employment details"
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
