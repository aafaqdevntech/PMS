require "test_helper"

class ProfileTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(username: "alice", email: "alice@example.com", password: "password123")
  end

  test "full_name is required" do
    profile = Profile.new(user: @user)
    assert_not profile.valid?
    assert_includes profile.errors[:full_name], "can't be blank"
  end

  test "user_id must be unique" do
    Profile.create!(user: @user, full_name: "Alice")

    dup = Profile.new(user: @user, full_name: "Alice Again")
    assert_not dup.valid?
    assert_includes dup.errors[:user_id], "has already been taken"
  end

  test "a profile with only full_name set is valid" do
    assert Profile.new(user: @user, full_name: "Alice").valid?
  end

  test "destroying a user destroys their profile" do
    profile = Profile.create!(user: @user, full_name: "Alice")
    @user.destroy!
    assert_nil Profile.find_by(id: profile.id)
  end
end
