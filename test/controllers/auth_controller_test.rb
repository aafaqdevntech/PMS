require "test_helper"

class AuthControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(username: "alice", email: "alice@example.com", password: "password123")
  end

  test "login then refresh returns a new access token" do
    post "/auth/login", params: { login: "alice", password: "password123" }
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
    post "/auth/login", params: { login: "alice@example.com", password: "password123" }
    assert_response :ok
  end

  test "wrong password is rejected" do
    post "/auth/login", params: { login: "alice", password: "nope" }
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

  test "refresh is rejected when RefreshToken.expires_at has passed, even if the JWT's own exp claim is still valid" do
    jti = SecureRandom.uuid
    @user.refresh_tokens.create!(jti: jti, expires_at: 1.day.ago)

    still_valid_jwt = JsonWebToken.encode({ user_id: @user.id, type: "refresh", jti: jti }, 1.hour.from_now)

    post "/auth/refresh", params: { refresh_token: still_valid_jwt }
    assert_response :unauthorized
  end

  test "refresh succeeds when RefreshToken.expires_at is still in the future" do
    jti = SecureRandom.uuid
    @user.refresh_tokens.create!(jti: jti, expires_at: 1.hour.from_now)

    valid_jwt = JsonWebToken.encode({ user_id: @user.id, type: "refresh", jti: jti }, 1.hour.from_now)

    post "/auth/refresh", params: { refresh_token: valid_jwt }
    assert_response :ok
    assert JSON.parse(response.body)["access_token"].present?
  end

  test "access token cannot be used at the refresh endpoint" do
    post "/auth/login", params: { login: "alice", password: "password123" }
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

  # --- logout ---

  test "logout revokes the refresh token; it can no longer be used to refresh" do
    post "/auth/login", params: { login: "alice", password: "password123" }
    body = JSON.parse(response.body)

    post "/auth/logout", params: { refresh_token: body["refresh_token"] },
      headers: auth_headers(body["access_token"])
    assert_response :ok
    assert_equal "Logged out", JSON.parse(response.body)["message"]

    post "/auth/refresh", params: { refresh_token: body["refresh_token"] }
    assert_response :unauthorized
  end

  test "logging out one session leaves the other sessions of the same user intact" do
    post "/auth/login", params: { login: "alice", password: "password123" }
    session_a = JSON.parse(response.body)

    post "/auth/login", params: { login: "alice", password: "password123" }
    session_b = JSON.parse(response.body)

    post "/auth/logout", params: { refresh_token: session_a["refresh_token"] },
      headers: auth_headers(session_a["access_token"])
    assert_response :ok

    post "/auth/refresh", params: { refresh_token: session_b["refresh_token"] }
    assert_response :ok, "session B must still be able to refresh after session A logs out"
  end

  test "logout without an access token is rejected" do
    post "/auth/login", params: { login: "alice", password: "password123" }
    refresh_token = JSON.parse(response.body)["refresh_token"]

    post "/auth/logout", params: { refresh_token: refresh_token }
    assert_response :unauthorized
  end

  test "logout cannot revoke another user's session" do
    other = User.create!(username: "bob", email: "bob@example.com", password: "password123")

    post "/auth/login", params: { login: "alice", password: "password123" }
    alice_refresh_token = JSON.parse(response.body)["refresh_token"]

    post "/auth/login", params: { login: "bob", password: "password123" }
    bob_access_token = JSON.parse(response.body)["access_token"]

    post "/auth/logout", params: { refresh_token: alice_refresh_token },
      headers: auth_headers(bob_access_token)
    assert_response :unauthorized

    post "/auth/refresh", params: { refresh_token: alice_refresh_token }
    assert_response :ok, "alice's session must survive bob's attempt to revoke it"
  end

  test "logout is idempotent" do
    post "/auth/login", params: { login: "alice", password: "password123" }
    body = JSON.parse(response.body)

    2.times do
      post "/auth/logout", params: { refresh_token: body["refresh_token"] },
        headers: auth_headers(body["access_token"])
      assert_response :ok
    end
  end

  test "malformed refresh_token at logout is rejected, not a 500" do
    post "/auth/login", params: { login: "alice", password: "password123" }
    access_token = JSON.parse(response.body)["access_token"]

    post "/auth/logout", params: { refresh_token: 12345 }.to_json,
      headers: auth_headers(access_token).merge("Content-Type" => "application/json")
    assert_response :unauthorized

    post "/auth/logout", params: {}, headers: auth_headers(access_token)
    assert_response :unauthorized
  end

  test "logout revokes only the refresh token — the access token keeps working until it expires" do
    post "/auth/login", params: { login: "alice", password: "password123" }
    body = JSON.parse(response.body)

    post "/auth/logout", params: { refresh_token: body["refresh_token"] },
      headers: auth_headers(body["access_token"])
    assert_response :ok

    get "/me", headers: auth_headers(body["access_token"])
    assert_response :ok, "the access token minted before logout is still valid until its own expiry"
  end

  private

  def auth_headers(token)
    { "Authorization" => "Bearer #{token}" }
  end
end
