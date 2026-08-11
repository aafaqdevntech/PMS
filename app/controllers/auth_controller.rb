class AuthController < ApplicationController
  skip_before_action :authenticate_user!, only: [:login, :refresh]

  ACCESS_TOKEN_TTL = 15.minutes
  REFRESH_TOKEN_TTL = 7.days

  def login
    user = User.find_by(username: login_params[:login]) ||
           User.find_by(email: login_params[:login])

    if user&.authenticate(login_params[:password])
      jti = SecureRandom.uuid
      user.refresh_tokens.create!(jti: jti, expires_at: REFRESH_TOKEN_TTL.from_now)

      render json: {
        user: UserSerializer.new(user),
        access_token: JsonWebToken.encode({ user_id: user.id, type: "access" }, ACCESS_TOKEN_TTL.from_now),
        refresh_token: JsonWebToken.encode({ user_id: user.id, type: "refresh", jti: jti }, REFRESH_TOKEN_TTL.from_now)
      }, status: :ok
    else
      render json: { error: "Invalid username/email or password" }, status: :unauthorized
    end
  end

  def refresh
    token = refresh_token_from(refresh_params[:refresh_token])

    if token && !token.revoked? && !token.expired?
      render json: {
        access_token: JsonWebToken.encode({ user_id: token.user_id, type: "access" }, ACCESS_TOKEN_TTL.from_now)
      }, status: :ok
    else
      render json: { error: "Invalid refresh token" }, status: :unauthorized
    end
  end

  # POST /auth/logout  { refresh_token }  (requires a valid access token)
  # Revokes only the session this refresh token belongs to — other devices
  # logged in as the same user are unaffected. An access token already
  # issued for this session keeps working until its own (short) expiry;
  # this only stops a new one from being minted. Revoking an already-revoked
  # token is a no-op, not an error — calling logout twice is fine.
  def logout
    token = refresh_token_from(logout_params[:refresh_token])

    if token && token.user_id == current_user.id
      token.update!(revoked_at: Time.current) unless token.revoked?
      render json: { message: "Logged out" }, status: :ok
    else
      render json: { error: "Invalid refresh token" }, status: :unauthorized
    end
  end

  private

  # Decodes a refresh JWT and resolves it to its RefreshToken row, revoked
  # or not — callers apply their own revoked?/ownership checks on top.
  def refresh_token_from(raw_token)
    payload = JsonWebToken.decode(raw_token)
    return nil unless payload && payload["type"] == "refresh"

    RefreshToken.find_by(jti: payload["jti"])
  end

  def login_params
    params.permit(:login, :password)
  end

  def refresh_params
    params.permit(:refresh_token)
  end

  def logout_params
    params.permit(:refresh_token)
  end
end
