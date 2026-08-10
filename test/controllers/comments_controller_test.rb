require "test_helper"

class CommentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @team = Team.create!(name: "Team A")
    @other_team = Team.create!(name: "Team B")

    @admin = User.create!(username: "admin", email: "admin@example.com", password: "password123")
    EmploymentDetail.create!(user: @admin, role: :admin, job_position: "Admin", joined_at: Time.current)

    @lead = User.create!(username: "lead", email: "lead@example.com", password: "password123")
    EmploymentDetail.create!(user: @lead, team: @team, role: :team_lead, job_position: "Lead", joined_at: Time.current)
    @team.update!(team_lead: @lead)

    @author = User.create!(username: "author", email: "author@example.com", password: "password123")
    EmploymentDetail.create!(user: @author, team: @team, role: :member, job_position: "Engineer", joined_at: Time.current)

    @teammate = User.create!(username: "teammate", email: "teammate@example.com", password: "password123")
    EmploymentDetail.create!(user: @teammate, team: @team, role: :member, job_position: "Engineer", joined_at: Time.current)

    # Leads Team B, so they can raise/create there — and still have no
    # standing whatsoever on Team A's issues, tasks or comments.
    @outsider = User.create!(username: "outsider", email: "outsider@example.com", password: "password123")
    EmploymentDetail.create!(user: @outsider, team: @other_team, role: :member, job_position: "Engineer", joined_at: Time.current)
    @other_team.update!(team_lead: @outsider)

    # No employment detail at all — no team, so nothing to read.
    @unassigned = User.create!(username: "unassigned", email: "unassigned@example.com", password: "password123")

    @project = Project.create!(title: "Project A", team: @team, created_by: @admin, status: :active)
    @other_project = Project.create!(title: "Project B", team: @other_team, created_by: @admin, status: :active)

    @issue = Issue.create!(title: "Bug", description: "It breaks", project: @project, raised_by: @author)
    @task = Task.create!(title: "Ship it", description: "Do the work", project: @project, created_by: @lead)

    @other_issue = Issue.create!(title: "Their bug", description: "Theirs", project: @other_project,
                                 raised_by: @outsider)
    @other_task = Task.create!(title: "Their task", description: "Theirs", project: @other_project,
                               created_by: @outsider)

    @issue_comment = Comment.create!(commentable: @issue, user: @author, body: "On the issue")
    @task_comment = Comment.create!(commentable: @task, user: @author, body: "On the task")

    @admin_token = login(@admin)
    @lead_token = login(@lead)
    @author_token = login(@author)
    @teammate_token = login(@teammate)
    @outsider_token = login(@outsider)
    @unassigned_token = login(@unassigned)
  end

  # --- creating ---

  test "a teammate comments on an issue; user_id is forced to the current user" do
    post "/issues/#{@issue.id}/comments",
      params: { body: "Looks related to the cache", user_id: @lead.id,
                commentable_type: "Task", commentable_id: @task.id },
      headers: auth_headers(@teammate_token)

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal @teammate.id, body["user_id"]
    assert_equal "Issue", body["commentable_type"]
    assert_equal @issue.id, body["commentable_id"]
    assert_equal "Looks related to the cache", body["body"]
  end

  test "a teammate comments on a task" do
    post "/tasks/#{@task.id}/comments", params: { body: "Starting on this" },
      headers: auth_headers(@teammate_token)

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "Task", body["commentable_type"]
    assert_equal @task.id, body["commentable_id"]
  end

  test "the team lead can comment like any other member" do
    post "/issues/#{@issue.id}/comments", params: { body: "Prioritising this" },
      headers: auth_headers(@lead_token)
    assert_response :created

    post "/tasks/#{@task.id}/comments", params: { body: "Assigning shortly" },
      headers: auth_headers(@lead_token)
    assert_response :created
  end

  test "an outsider cannot comment on another team's issue or task" do
    post "/issues/#{@issue.id}/comments", params: { body: "Nosy" }, headers: auth_headers(@outsider_token)
    assert_response :forbidden

    post "/tasks/#{@task.id}/comments", params: { body: "Nosy" }, headers: auth_headers(@outsider_token)
    assert_response :forbidden

    assert_equal 1, @issue.comments.count
    assert_equal 1, @task.comments.count
  end

  test "a user with no team cannot comment" do
    post "/issues/#{@issue.id}/comments", params: { body: "Hello" }, headers: auth_headers(@unassigned_token)
    assert_response :forbidden
  end

  test "an admin cannot comment" do
    post "/issues/#{@issue.id}/comments", params: { body: "Admin says" }, headers: auth_headers(@admin_token)
    assert_response :forbidden

    post "/tasks/#{@task.id}/comments", params: { body: "Admin says" }, headers: auth_headers(@admin_token)
    assert_response :forbidden
  end

  test "body is required and capped at 5000 characters" do
    post "/issues/#{@issue.id}/comments", params: { body: "" }, headers: auth_headers(@author_token)
    assert_response :unprocessable_entity

    post "/issues/#{@issue.id}/comments", params: { body: "a" * 5001 }, headers: auth_headers(@author_token)
    assert_response :unprocessable_entity

    post "/issues/#{@issue.id}/comments", params: { body: "a" * 5000 }, headers: auth_headers(@author_token)
    assert_response :created
  end

  test "commenting on a missing parent is a 404" do
    post "/issues/#{Issue.maximum(:id) + 1}/comments", params: { body: "Ghost" },
      headers: auth_headers(@author_token)
    assert_response :not_found
  end

  # --- reading ---

  test "teammates and admin can list an issue's and a task's comments" do
    [@author_token, @teammate_token, @lead_token, @admin_token].each do |token|
      get "/issues/#{@issue.id}/comments", headers: auth_headers(token)
      assert_response :ok
      assert_equal [@issue_comment.id], JSON.parse(response.body).map { |c| c["id"] }

      get "/tasks/#{@task.id}/comments", headers: auth_headers(token)
      assert_response :ok
      assert_equal [@task_comment.id], JSON.parse(response.body).map { |c| c["id"] }
    end
  end

  test "comments come back oldest first" do
    second = Comment.create!(commentable: @issue, user: @teammate, body: "Second", created_at: 1.hour.from_now)
    first = Comment.create!(commentable: @issue, user: @teammate, body: "First", created_at: 1.hour.ago)

    get "/issues/#{@issue.id}/comments", headers: auth_headers(@author_token)
    assert_response :ok
    assert_equal [first.id, @issue_comment.id, second.id], JSON.parse(response.body).map { |c| c["id"] }
  end

  test "an outsider cannot read another team's comments" do
    get "/issues/#{@issue.id}/comments", headers: auth_headers(@outsider_token)
    assert_response :forbidden

    get "/tasks/#{@task.id}/comments", headers: auth_headers(@outsider_token)
    assert_response :forbidden
  end

  test "a user with no team cannot read comments" do
    get "/issues/#{@issue.id}/comments", headers: auth_headers(@unassigned_token)
    assert_response :forbidden
  end

  test "the listing never leaks another team's comments" do
    Comment.create!(commentable: @other_issue, user: @outsider, body: "Theirs")

    get "/issues/#{@other_issue.id}/comments", headers: auth_headers(@author_token)
    assert_response :forbidden

    get "/issues/#{@other_issue.id}/comments", headers: auth_headers(@admin_token)
    assert_response :ok
    assert_equal ["Theirs"], JSON.parse(response.body).map { |c| c["body"] }
  end

  # --- editing ---

  test "the author edits their own comment" do
    patch "/comments/#{@issue_comment.id}", params: { body: "Edited" }, headers: auth_headers(@author_token)

    assert_response :ok
    assert_equal "Edited", @issue_comment.reload.body
  end

  test "editing cannot move a comment to another parent or another user" do
    patch "/comments/#{@issue_comment.id}",
      params: { body: "Edited", user_id: @teammate.id, commentable_type: "Task", commentable_id: @task.id },
      headers: auth_headers(@author_token)

    assert_response :ok
    @issue_comment.reload
    assert_equal @author.id, @issue_comment.user_id
    assert_equal "Issue", @issue_comment.commentable_type
    assert_equal @issue.id, @issue_comment.commentable_id
  end

  test "nobody but the author can edit a comment" do
    [@teammate_token, @lead_token, @admin_token, @outsider_token].each do |token|
      patch "/comments/#{@issue_comment.id}", params: { body: "Not mine" }, headers: auth_headers(token)
      assert_response :forbidden
    end
    assert_equal "On the issue", @issue_comment.reload.body
  end

  # --- deleting ---

  test "the author deletes their own comment" do
    delete "/comments/#{@task_comment.id}", headers: auth_headers(@author_token)

    assert_response :no_content
    assert_nil Comment.find_by(id: @task_comment.id)
  end

  test "an admin deletes any comment on any team" do
    other = Comment.create!(commentable: @other_task, user: @outsider, body: "Theirs")

    delete "/comments/#{@issue_comment.id}", headers: auth_headers(@admin_token)
    assert_response :no_content

    delete "/comments/#{other.id}", headers: auth_headers(@admin_token)
    assert_response :no_content
  end

  test "a teammate, the lead and an outsider cannot delete someone else's comment" do
    [@teammate_token, @lead_token, @outsider_token].each do |token|
      delete "/comments/#{@issue_comment.id}", headers: auth_headers(token)
      assert_response :forbidden
    end
    assert Comment.exists?(@issue_comment.id)
  end

  # --- cascades ---

  test "deleting an issue or a task takes its comments with it" do
    delete "/issues/#{@issue.id}", headers: auth_headers(@author_token)
    assert_response :no_content
    assert_nil Comment.find_by(id: @issue_comment.id)

    delete "/tasks/#{@task.id}", headers: auth_headers(@lead_token)
    assert_response :no_content
    assert_nil Comment.find_by(id: @task_comment.id)
  end

  test "deleting a user takes their comments with them" do
    theirs = Comment.create!(commentable: @issue, user: @teammate, body: "Mine")

    delete "/users/#{@teammate.id}", headers: auth_headers(@admin_token)
    assert_response :no_content

    assert_nil Comment.find_by(id: theirs.id)
    assert Comment.exists?(@issue_comment.id), "other authors' comments must survive"
  end

  # --- closed parents ---

  test "a closed issue keeps its conversation open" do
    post "/issues/#{@issue.id}/resolve", params: { resolution_note: "Fixed" },
      headers: auth_headers(@lead_token)
    assert_response :ok

    get "/issues/#{@issue.id}/comments", headers: auth_headers(@teammate_token)
    assert_response :ok

    post "/issues/#{@issue.id}/comments", params: { body: "Confirming the fix" },
      headers: auth_headers(@teammate_token)
    assert_response :created

    patch "/comments/#{@issue_comment.id}", params: { body: "Edited after close" },
      headers: auth_headers(@author_token)
    assert_response :ok

    delete "/comments/#{@issue_comment.id}", headers: auth_headers(@author_token)
    assert_response :no_content
  end

  test "an admin purging a closed issue takes its comments with it" do
    post "/issues/#{@issue.id}/resolve", params: { resolution_note: "Fixed" },
      headers: auth_headers(@lead_token)
    assert_response :ok

    delete "/issues/#{@issue.id}", headers: auth_headers(@admin_token)
    assert_response :no_content

    assert_nil Comment.find_by(id: @issue_comment.id)
    assert Comment.exists?(@task_comment.id), "the task's comments are untouched"
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
