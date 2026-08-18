require "test_helper"

class IssueNotifierTest < ActiveSupport::TestCase
  setup do
    @team = Team.create!(name: "Team A")

    @admin = User.create!(username: "admin", email: "admin@example.com", password: "password123")
    EmploymentDetail.create!(user: @admin, role: :admin, job_position: "Admin", joined_at: Time.current)

    @lead = User.create!(username: "lead", email: "lead@example.com", password: "password123")
    EmploymentDetail.create!(user: @lead, team: @team, role: :team_lead, job_position: "Lead", joined_at: Time.current)
    @team.update!(team_lead: @lead)

    @member = User.create!(username: "member", email: "member@example.com", password: "password123")
    EmploymentDetail.create!(user: @member, team: @team, role: :member, job_position: "Engineer", joined_at: Time.current)

    @teammate = User.create!(username: "teammate", email: "teammate@example.com", password: "password123")
    EmploymentDetail.create!(user: @teammate, team: @team, role: :member, job_position: "Engineer", joined_at: Time.current)

    @project = Project.create!(title: "Project A", team: @team, created_by: @admin, status: :active)
    @issue = Issue.create!(title: "Bug", project: @project, raised_by: @member)
  end

  test "notifies every other team member, excluding the actor, on issue_raised" do
    assert_difference("Notification.count", 2) do
      IssueNotifier.notify(issue: @issue, actor: @member, event_type: "issue_raised")
    end

    recipients = Notification.where(issue: @issue).pluck(:recipient_id)
    assert_equal [@lead.id, @teammate.id].sort, recipients.sort
    assert_not_includes recipients, @member.id
  end

  test "notifies every other team member, excluding the actor, on issue_resolved" do
    @issue.update!(status: :resolved, resolution_note: "Fixed")

    assert_difference("Notification.count", 2) do
      IssueNotifier.notify(issue: @issue, actor: @lead, event_type: "issue_resolved")
    end

    recipients = Notification.where(issue: @issue).pluck(:recipient_id)
    assert_equal [@member.id, @teammate.id].sort, recipients.sort
    assert_not_includes recipients, @lead.id
  end

  test "stores the given event_type on each notification" do
    IssueNotifier.notify(issue: @issue, actor: @member, event_type: "issue_raised")

    assert Notification.where(issue: @issue, event_type: "issue_raised").exists?
  end

  test "creates no notifications when the project has no team" do
    @project.update!(team_id: nil)

    assert_no_difference("Notification.count") do
      IssueNotifier.notify(issue: @issue.reload, actor: @member, event_type: "issue_raised")
    end
  end

  test "broadcasts one message per recipient's own notification stream" do
    assert_broadcasts(NotificationsChannel.broadcasting_for(@lead), 1) do
      assert_broadcasts(NotificationsChannel.broadcasting_for(@teammate), 1) do
        IssueNotifier.notify(issue: @issue, actor: @member, event_type: "issue_raised")
      end
    end
  end
end
