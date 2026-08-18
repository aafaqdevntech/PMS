require "test_helper"

class NotificationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @team = Team.create!(name: "Team A")

    @admin = User.create!(username: "admin", email: "admin@example.com", password: "password123")
    EmploymentDetail.create!(user: @admin, role: :admin, job_position: "Admin", joined_at: Time.current)

    @lead = User.create!(username: "lead", email: "lead@example.com", password: "password123")
    EmploymentDetail.create!(user: @lead, team: @team, role: :team_lead, job_position: "Lead", joined_at: Time.current)
    @team.update!(team_lead: @lead)

    @member = User.create!(username: "member", email: "member@example.com", password: "password123")
    EmploymentDetail.create!(user: @member, team: @team, role: :member, job_position: "Engineer", joined_at: Time.current)

    @project = Project.create!(title: "Project A", team: @team, created_by: @admin, status: :active)
    @issue = Issue.create!(title: "Bug", project: @project, raised_by: @member)

    @lead_notification = Notification.create!(recipient: @lead, actor: @member, issue: @issue, event_type: :issue_raised)
    @member_notification = Notification.create!(recipient: @member, actor: @lead, issue: @issue, event_type: :issue_resolved)

    @lead_token = login(@lead)
    @member_token = login(@member)
  end

  test "index only returns the caller's own notifications" do
    get "/notifications", headers: auth_headers(@lead_token)

    assert_response :success
    ids = JSON.parse(response.body).map { |n| n["id"] }
    assert_equal [@lead_notification.id], ids
  end

  test "read marks the caller's own notification as read" do
    patch "/notifications/#{@lead_notification.id}/read", headers: auth_headers(@lead_token)

    assert_response :success
    assert @lead_notification.reload.read?
  end

  test "read is forbidden for a notification that belongs to someone else" do
    patch "/notifications/#{@member_notification.id}/read", headers: auth_headers(@lead_token)

    assert_response :forbidden
    assert_not @member_notification.reload.read?
  end

  test "read_all marks only the caller's own unread notifications as read" do
    patch "/notifications/read_all", headers: auth_headers(@lead_token)

    assert_response :no_content
    assert @lead_notification.reload.read?
    assert_not @member_notification.reload.read?
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
