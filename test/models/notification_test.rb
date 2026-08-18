require "test_helper"

class NotificationTest < ActiveSupport::TestCase
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
  end

  def new_notification(attrs = {})
    Notification.new({ recipient: @lead, actor: @member, issue: @issue, event_type: :issue_raised }.merge(attrs))
  end

  test "a well-formed notification is valid" do
    assert new_notification.valid?
  end

  # validate: true keeps bad input out of the ArgumentError path, same as Task's
  # priority/status enums.
  test "an unknown event_type is invalid rather than raising" do
    notification = new_notification
    notification.event_type = "bogus"
    assert_not notification.valid?
    assert_includes notification.errors[:event_type], "is not included in the list"
  end

  test "unread scope returns only notifications with a nil read_at" do
    unread = new_notification.tap(&:save!)
    read = new_notification(event_type: :issue_resolved, read_at: Time.current).tap(&:save!)

    assert_includes Notification.unread, unread
    assert_not_includes Notification.unread, read
  end

  test "read? reflects read_at" do
    notification = new_notification
    assert_not notification.read?

    notification.read_at = Time.current
    assert notification.read?
  end

  test "destroying the issue destroys its notifications" do
    new_notification.save!

    assert_difference("Notification.count", -1) { @issue.destroy! }
  end

  test "destroying the recipient destroys their received notifications" do
    new_notification.save!

    assert_difference("Notification.count", -1) { @lead.destroy! }
  end

  test "destroying a user who is still an actor on a notification is blocked" do
    # @lead as actor (e.g. the lead who resolved the issue), notifying @member
    # — isolates the restriction from raised_issues, which already protects
    # @member for an unrelated reason.
    new_notification(recipient: @member, actor: @lead, event_type: :issue_resolved).save!

    result = @lead.destroy
    assert_equal false, result
    assert User.exists?(@lead.id)
  end
end
