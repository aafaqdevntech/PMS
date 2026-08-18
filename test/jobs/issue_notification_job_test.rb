require "test_helper"

class IssueNotificationJobTest < ActiveJob::TestCase
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

  test "notifies the rest of the team via IssueNotifier" do
    assert_difference("Notification.count", 1) do
      IssueNotificationJob.perform_now(issue_id: @issue.id, actor_id: @member.id, event_type: "issue_raised")
    end

    assert_equal @lead.id, Notification.last.recipient_id
  end

  test "is discarded, not retried, when the issue no longer exists" do
    bogus_id = @issue.id
    @issue.destroy!

    assert_nothing_raised do
      perform_enqueued_jobs do
        IssueNotificationJob.perform_later(issue_id: bogus_id, actor_id: @member.id, event_type: "issue_raised")
      end
    end
  end

  test "is discarded, not retried, when the actor no longer exists" do
    bogus_id = @lead.id
    @lead.destroy!

    assert_nothing_raised do
      perform_enqueued_jobs do
        IssueNotificationJob.perform_later(issue_id: @issue.id, actor_id: bogus_id, event_type: "issue_raised")
      end
    end
  end
end
