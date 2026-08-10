require "test_helper"

class CommentTest < ActiveSupport::TestCase
  setup do
    @team = Team.create!(name: "Team A")

    @admin = User.create!(username: "admin", email: "admin@example.com", password: "password123")
    EmploymentDetail.create!(user: @admin, role: :admin, job_position: "Admin", joined_at: Time.current)

    @lead = User.create!(username: "lead", email: "lead@example.com", password: "password123")
    EmploymentDetail.create!(user: @lead, team: @team, role: :team_lead, job_position: "Lead", joined_at: Time.current)
    @team.update!(team_lead: @lead)

    @user = User.create!(username: "alice", email: "alice@example.com", password: "password123")
    EmploymentDetail.create!(user: @user, team: @team, role: :member, job_position: "Eng", joined_at: Time.current)

    @project = Project.create!(title: "P", team: @team, created_by: @admin, status: :active)
    @issue = Issue.create!(title: "Bug", project: @project, raised_by: @user)
    @task = Task.create!(title: "T", description: "d", project: @project, created_by: @lead)
  end

  test "body is required and capped at 5000 characters" do
    blank = Comment.new(commentable: @issue, user: @user, body: "")
    assert_not blank.valid?
    assert_includes blank.errors[:body], "can't be blank"

    long = Comment.new(commentable: @issue, user: @user, body: "a" * 5001)
    assert_not long.valid?
    assert_includes long.errors[:body], "is too long (maximum is 5000 characters)"
  end

  test "commentable_type must be Issue or Task" do
    comment = Comment.new(commentable_type: "Project", commentable_id: @project.id, user: @user, body: "hi")
    assert_not comment.valid?
    assert_includes comment.errors[:commentable_type], "is not included in the list"
  end

  test "a comment can attach to an issue or a task" do
    assert Comment.new(commentable: @issue, user: @user, body: "hi").valid?
    assert Comment.new(commentable: @task, user: @user, body: "hi").valid?
  end

  test "commentable_exists rejects a dangling id, since a polymorphic parent has no database foreign key" do
    comment = Comment.new(commentable_type: "Issue", commentable_id: Issue.maximum(:id).to_i + 1000,
                           user: @user, body: "hi")
    assert_not comment.valid?
    assert_includes comment.errors[:commentable], "must exist"
  end

  test "team_id is derived through the commentable's project" do
    issue_comment = Comment.create!(commentable: @issue, user: @user, body: "hi")
    assert_equal @team.id, issue_comment.team_id

    task_comment = Comment.create!(commentable: @task, user: @user, body: "hi")
    assert_equal @team.id, task_comment.team_id
  end

  test "author? checks user_id" do
    comment = Comment.create!(commentable: @issue, user: @user, body: "hi")
    assert comment.author?(@user)
    assert_not comment.author?(@lead)
    assert_not comment.author?(nil)
  end

  test "destroying the issue or the task destroys its comments" do
    issue_comment = Comment.create!(commentable: @issue, user: @user, body: "hi")
    task_comment = Comment.create!(commentable: @task, user: @user, body: "hi")

    @issue.destroy!
    assert_nil Comment.find_by(id: issue_comment.id)

    @task.destroy!
    assert_nil Comment.find_by(id: task_comment.id)
  end
end
