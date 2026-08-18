require "test_helper"

class ApplicationCable::ConnectionTest < ActionCable::Connection::TestCase
  setup do
    @user = User.create!(username: "member", email: "member@example.com", password: "password123")
    EmploymentDetail.create!(user: @user, role: :member, job_position: "Engineer", joined_at: Time.current)
  end

  test "connects when given a valid access token" do
    token = JsonWebToken.encode({ user_id: @user.id, type: "access" }, 15.minutes.from_now)

    connect params: { token: token }

    assert_equal @user.id, connection.current_user.id
  end

  test "rejects a connection with no token" do
    assert_reject_connection { connect }
  end

  test "rejects a connection with a garbage token" do
    assert_reject_connection { connect params: { token: "not-a-real-token" } }
  end

  test "rejects a connection with an expired token" do
    token = JsonWebToken.encode({ user_id: @user.id, type: "access" }, 1.minute.ago)

    assert_reject_connection { connect params: { token: token } }
  end

  test "rejects a refresh token, even though it's otherwise valid" do
    token = JsonWebToken.encode({ user_id: @user.id, type: "refresh" }, 15.minutes.from_now)

    assert_reject_connection { connect params: { token: token } }
  end
end
