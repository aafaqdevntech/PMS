require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "authenticate returns truthy for the correct password, false otherwise" do
    user = User.create!(username: "alice", email: "alice@example.com", password: "password123")
    assert user.authenticate("password123")
    assert_not user.authenticate("wrong")
  end

  test "password is required on create" do
    user = User.new(username: "nopass", email: "nopass@example.com")
    assert_not user.valid?
    assert_includes user.errors[:password], "can't be blank"
  end

  test "username and email must be present" do
    user = User.new(password: "password123")
    assert_not user.valid?
    assert_includes user.errors[:username], "can't be blank"
    assert_includes user.errors[:email], "can't be blank"
  end

  test "username and email are unique, case-insensitively" do
    User.create!(username: "Alice", email: "alice@example.com", password: "password123")

    dup_username = User.new(username: "alice", email: "other@example.com", password: "password123")
    assert_not dup_username.valid?
    assert_includes dup_username.errors[:username], "has already been taken"

    dup_email = User.new(username: "other", email: "ALICE@example.com", password: "password123")
    assert_not dup_email.valid?
    assert_includes dup_email.errors[:email], "has already been taken"
  end

  test "email must be a valid format" do
    user = User.new(username: "bob", email: "not-an-email", password: "password123")
    assert_not user.valid?
    assert_includes user.errors[:email], "is invalid"
  end

  test "admin? is false when there is no employment_detail" do
    user = User.create!(username: "solo", email: "solo@example.com", password: "password123")
    assert_not user.admin?
  end

  test "admin? reflects the employment_detail role" do
    boss = User.create!(username: "boss", email: "boss@example.com", password: "password123")
    EmploymentDetail.create!(user: boss, role: :admin, job_position: "Admin", joined_at: Time.current)
    assert boss.admin?

    worker = User.create!(username: "worker", email: "worker@example.com", password: "password123")
    EmploymentDetail.create!(user: worker, role: :member, job_position: "Eng", joined_at: Time.current)
    assert_not worker.admin?
  end

  # --- password reset ---

  test "generate_password_reset_token! returns the raw token and stores only its digest" do
    user = User.create!(username: "carol", email: "carol@example.com", password: "password123")
    raw_token = user.generate_password_reset_token!

    assert_not_nil raw_token
    assert_not_equal raw_token, user.reset_password_token
    assert_equal User.digest_token(raw_token), user.reset_password_token
    assert_not_nil user.reset_password_sent_at
  end

  test "password_reset_token_valid? is true within 2 hours and false after" do
    user = User.create!(username: "dave", email: "dave@example.com", password: "password123")
    user.generate_password_reset_token!
    assert user.password_reset_token_valid?

    travel 3.hours do
      assert_not user.password_reset_token_valid?
    end
  end

  test "password_reset_token_valid? is false when no token was ever generated" do
    user = User.create!(username: "erin", email: "erin@example.com", password: "password123")
    assert_not user.password_reset_token_valid?
  end

  test "clear_password_reset_token! nils out both fields" do
    user = User.create!(username: "frank", email: "frank@example.com", password: "password123")
    user.generate_password_reset_token!

    user.clear_password_reset_token!
    assert_nil user.reset_password_token
    assert_nil user.reset_password_sent_at
  end

  test "find_by_reset_token finds the user by the digest of the raw token" do
    user = User.create!(username: "gina", email: "gina@example.com", password: "password123")
    raw_token = user.generate_password_reset_token!

    assert_equal user, User.find_by_reset_token(raw_token)
    assert_nil User.find_by_reset_token("garbage")
    assert_nil User.find_by_reset_token(nil)
    assert_nil User.find_by_reset_token("")
  end

  # --- dependent associations ---

  test "deleting a user destroys their profile, employment_detail, comments, and refresh_tokens" do
    team = Team.create!(name: "Propane")
    admin = User.create!(username: "admin2", email: "admin2@example.com", password: "password123")
    EmploymentDetail.create!(user: admin, role: :admin, job_position: "Admin", joined_at: Time.current)

    user = User.create!(username: "hank", email: "hank@example.com", password: "password123")
    Profile.create!(user: user, full_name: "Hank Hill")
    EmploymentDetail.create!(user: user, team: team, role: :member, job_position: "Eng", joined_at: Time.current)

    # The issue is raised by someone else so this test stays isolated from the
    # separate raised_by-foreign-key gap documented below.
    project = Project.create!(title: "P", team: team, created_by: admin, status: :active)
    other_member = User.create!(username: "other_member", email: "other_member@example.com", password: "password123")
    EmploymentDetail.create!(user: other_member, team: team, role: :member, job_position: "Eng", joined_at: Time.current)
    issue = Issue.create!(title: "Bug", project: project, raised_by: other_member)

    comment = Comment.create!(commentable: issue, user: user, body: "hi")
    token = RefreshToken.create!(user: user, jti: SecureRandom.uuid, expires_at: 7.days.from_now)

    user.destroy!

    assert_nil Profile.find_by(user_id: user.id)
    assert_nil EmploymentDetail.find_by(user_id: user.id)
    assert_nil Comment.find_by(id: comment.id)
    assert_nil RefreshToken.find_by(id: token.id)
  end

  test "deleting a user who raised an issue is blocked, mirroring created_tasks" do
    team = Team.create!(name: "Foreign Key Gap")
    admin = User.create!(username: "admin4", email: "admin4@example.com", password: "password123")
    EmploymentDetail.create!(user: admin, role: :admin, job_position: "Admin", joined_at: Time.current)

    raiser = User.create!(username: "raiser", email: "raiser@example.com", password: "password123")
    EmploymentDetail.create!(user: raiser, team: team, role: :member, job_position: "Eng", joined_at: Time.current)

    project = Project.create!(title: "P", team: team, created_by: admin, status: :active)
    Issue.create!(title: "Bug", project: project, raised_by: raiser)

    result = raiser.destroy
    assert_equal false, result
    assert User.exists?(raiser.id)
  end

  test "deleting an assignee nullifies their assigned tasks, but a lead with created_tasks cannot be deleted" do
    team = Team.create!(name: "Strickland")
    lead = User.create!(username: "lead2", email: "lead2@example.com", password: "password123")
    EmploymentDetail.create!(user: lead, team: team, role: :team_lead, job_position: "Lead", joined_at: Time.current)
    team.update!(team_lead: lead)

    assignee = User.create!(username: "assignee2", email: "assignee2@example.com", password: "password123")
    EmploymentDetail.create!(user: assignee, team: team, role: :member, job_position: "Eng", joined_at: Time.current)

    admin = User.create!(username: "admin3", email: "admin3@example.com", password: "password123")
    EmploymentDetail.create!(user: admin, role: :admin, job_position: "Admin", joined_at: Time.current)

    project = Project.create!(title: "P2", team: team, created_by: admin, status: :active)
    task = Task.create!(title: "T", description: "d", project: project, created_by: lead,
                         assigned_to: assignee, status: :assigned)

    assignee.destroy!
    assert_nil task.reload.assigned_to_id

    result = lead.destroy
    assert_equal false, result
    assert User.exists?(lead.id)
  end

  test "deleting a team lead nullifies the team's team_lead_id rather than being blocked" do
    team = Team.create!(name: "Nullify Co")
    lead = User.create!(username: "lead3", email: "lead3@example.com", password: "password123")
    EmploymentDetail.create!(user: lead, team: team, role: :team_lead, job_position: "Lead", joined_at: Time.current)
    team.update!(team_lead: lead)

    lead.destroy!

    assert_nil team.reload.team_lead_id
  end
end
