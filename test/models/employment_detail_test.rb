require "test_helper"

class EmploymentDetailTest < ActiveSupport::TestCase
  setup do
    @team = Team.create!(name: "Team A")
    @user = User.create!(username: "alice", email: "alice@example.com", password: "password123")
  end

  test "user_id must be unique" do
    EmploymentDetail.create!(user: @user, role: :member, job_position: "Eng", joined_at: Time.current)

    dup = EmploymentDetail.new(user: @user, role: :member, job_position: "Eng", joined_at: Time.current)
    assert_not dup.valid?
    assert_includes dup.errors[:user_id], "has already been taken"
  end

  test "job_position and joined_at are required, even though the database column allows null" do
    detail = EmploymentDetail.new(user: @user, role: :member)
    assert_not detail.valid?
    assert_includes detail.errors[:job_position], "can't be blank"
    assert_includes detail.errors[:joined_at], "can't be blank"
  end

  test "an admin cannot have a team" do
    detail = EmploymentDetail.new(user: @user, role: :admin, team: @team, job_position: "Admin", joined_at: Time.current)
    assert_not detail.valid?
    assert_includes detail.errors[:team], "must be blank for admins"
  end

  test "an admin with no team is valid" do
    detail = EmploymentDetail.new(user: @user, role: :admin, job_position: "Admin", joined_at: Time.current)
    assert detail.valid?
  end

  test "a team_lead or member can have a team" do
    lead = EmploymentDetail.new(user: @user, role: :team_lead, team: @team, job_position: "Lead", joined_at: Time.current)
    assert lead.valid?
  end

  test "role enum exposes admin, team_lead, and member" do
    assert_equal({ "admin" => 0, "team_lead" => 1, "member" => 2 }, EmploymentDetail.roles)
  end
end
