require "test_helper"

class TeamTest < ActiveSupport::TestCase
  test "name must be present and unique, case-insensitively" do
    Team.create!(name: "Engineering")

    blank = Team.new(name: "")
    assert_not blank.valid?
    assert_includes blank.errors[:name], "can't be blank"

    dup = Team.new(name: "engineering")
    assert_not dup.valid?
    assert_includes dup.errors[:name], "has already been taken"
  end

  test "team_lead_id can be nil for multiple teams, but cannot be shared by two teams" do
    lead = User.create!(username: "lead", email: "lead@example.com", password: "password123")

    Team.create!(name: "A", team_lead: nil)
    assert Team.new(name: "B", team_lead: nil).valid?

    Team.create!(name: "C", team_lead: lead)
    dup = Team.new(name: "D", team_lead: lead)
    assert_not dup.valid?
    assert_includes dup.errors[:team_lead_id], "has already been taken"
  end

  test "a team with employment_details cannot be destroyed" do
    team = Team.create!(name: "Staffed")
    user = User.create!(username: "member", email: "member@example.com", password: "password123")
    EmploymentDetail.create!(user: user, team: team, role: :member, job_position: "Eng", joined_at: Time.current)

    result = team.destroy
    assert_equal false, result
    assert Team.exists?(team.id)
  end

  test "a team with projects cannot be destroyed" do
    team = Team.create!(name: "Busy")
    admin = User.create!(username: "admin", email: "admin@example.com", password: "password123")
    Project.create!(title: "P", team: team, created_by: admin)

    result = team.destroy
    assert_equal false, result
    assert Team.exists?(team.id)
  end

  test "a team with no dependents deletes cleanly" do
    team = Team.create!(name: "Empty")
    assert team.destroy
  end
end
