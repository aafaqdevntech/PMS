require "test_helper"

class AuthControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(username: "alice", email: "alice@example.com", password: "password123")
  end

  test "login then refresh returns a new access token" do
    post "/auth/login", params: { username: "alice", password: "password123" }
    assert_response :ok
    body = JSON.parse(response.body)
    refresh_token = body["refresh_token"]
    assert refresh_token.present?

    post "/auth/refresh", params: { refresh_token: refresh_token }
    assert_response :ok, response.body
    body2 = JSON.parse(response.body)
    assert body2["access_token"].present?
  end

  test "login with email works too" do
    post "/auth/login", params: { username: "alice@example.com", password: "password123" }
    assert_response :ok
  end

  test "wrong password is rejected" do
    post "/auth/login", params: { username: "alice", password: "nope" }
    assert_response :unauthorized
  end

  test "expired refresh token is rejected" do
    expired_token = JWT.encode(
      { user_id: @user.id, type: "refresh", exp: 1.hour.ago.to_i },
      Rails.application.secret_key_base,
      "HS256"
    )
    post "/auth/refresh", params: { refresh_token: expired_token }
    assert_response :unauthorized
  end

  test "access token cannot be used at the refresh endpoint" do
    post "/auth/login", params: { username: "alice", password: "password123" }
    body = JSON.parse(response.body)
    access_token = body["access_token"]

    post "/auth/refresh", params: { refresh_token: access_token }
    assert_response :unauthorized
  end

  test "non-string refresh_token in a JSON body is rejected, not a 500" do
    post "/auth/refresh",
      params: { refresh_token: 12345 }.to_json,
      headers: { "Content-Type" => "application/json" }
    assert_response :unauthorized
  end

  test "array refresh_token in a JSON body is rejected, not a 500" do
    post "/auth/refresh",
      params: { refresh_token: ["a", "b"] }.to_json,
      headers: { "Content-Type" => "application/json" }
    assert_response :unauthorized
  end

  test "missing refresh_token param is rejected, not a 500" do
    post "/auth/refresh", params: {}
    assert_response :unauthorized
  end
end
