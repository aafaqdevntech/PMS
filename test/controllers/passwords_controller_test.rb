require "test_helper"

class PasswordsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(username: "alice", email: "alice@example.com", password: "password123")
  end

  # --- forgot (anti-enumeration) ---

  test "forgot with a registered email enqueues the reset email and returns the generic message" do
    assert_enqueued_emails 1 do
      post "/password/forgot", params: { email: @user.email }
    end
    assert_response :ok
    assert_equal "If that email is registered, password reset instructions have been sent.",
                 JSON.parse(response.body)["message"]
    assert_not_nil @user.reload.reset_password_token
  end

  test "forgot with an unregistered email returns the identical message and sends nothing" do
    assert_enqueued_emails 0 do
      post "/password/forgot", params: { email: "nobody@example.com" }
    end
    assert_response :ok
    assert_equal "If that email is registered, password reset instructions have been sent.",
                 JSON.parse(response.body)["message"]
  end

  test "forgot works without an access token" do
    post "/password/forgot", params: { email: @user.email }
    assert_response :ok
  end

  # --- reset ---

  test "reset with a valid token and matching passwords succeeds, and the token is single-use" do
    raw_token = @user.generate_password_reset_token!

    patch "/password/reset",
      params: { token: raw_token, password: "newpassword1", password_confirmation: "newpassword1" }
    assert_response :ok
    assert_equal "Password has been reset. You can now log in.", JSON.parse(response.body)["message"]

    @user.reload
    assert @user.authenticate("newpassword1")
    assert_nil @user.reset_password_token
    assert_nil @user.reset_password_sent_at

    # reusing the same (now-cleared) token fails
    patch "/password/reset",
      params: { token: raw_token, password: "another1", password_confirmation: "another1" }
    assert_response :unprocessable_entity
    assert_equal "That reset link is invalid or has expired.", JSON.parse(response.body)["error"]
  end

  test "reset with a token older than 2 hours is rejected as expired" do
    raw_token = @user.generate_password_reset_token!

    travel 3.hours do
      patch "/password/reset",
        params: { token: raw_token, password: "newpassword1", password_confirmation: "newpassword1" }
      assert_response :unprocessable_entity
      assert_equal "That reset link is invalid or has expired.", JSON.parse(response.body)["error"]
    end

    assert_not @user.reload.authenticate("newpassword1")
  end

  test "reset with an unknown or garbage token is rejected" do
    patch "/password/reset",
      params: { token: "not-a-real-token", password: "newpassword1", password_confirmation: "newpassword1" }
    assert_response :unprocessable_entity
    assert_equal "That reset link is invalid or has expired.", JSON.parse(response.body)["error"]
  end

  test "reset with a blank token is rejected" do
    patch "/password/reset", params: { token: "", password: "newpassword1", password_confirmation: "newpassword1" }
    assert_response :unprocessable_entity
  end

  test "reset with mismatched password_confirmation is rejected with validation errors, and the token survives" do
    raw_token = @user.generate_password_reset_token!

    patch "/password/reset",
      params: { token: raw_token, password: "newpassword1", password_confirmation: "different" }
    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert body["errors"].present?

    assert_not_nil @user.reload.reset_password_token
    assert_not @user.authenticate("newpassword1")
  end

  test "reset works without an access token" do
    raw_token = @user.generate_password_reset_token!
    patch "/password/reset",
      params: { token: raw_token, password: "newpassword1", password_confirmation: "newpassword1" }
    assert_response :ok
  end
end
