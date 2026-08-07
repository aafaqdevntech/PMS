class AuthController < ApplicationController
  skip_before_action :authenticate_user!, only: [:login, :refresh]

  ACCESS_TOKEN_TTL = 15.minutes
  REFRESH_TOKEN_TTL = 7.days

  def login
    user = User.find_by(username: login_params[:username]) ||
           User.find_by(email: login_params[:username])

    if user&.authenticate(login_params[:password])
      render json: {
        user: UserSerializer.new(user),
        access_token: JsonWebToken.encode({ user_id: user.id, type: "access" }, ACCESS_TOKEN_TTL.from_now),
        refresh_token: JsonWebToken.encode({ user_id: user.id, type: "refresh" }, REFRESH_TOKEN_TTL.from_now)
      }, status: :ok
    else
      render json: { error: "Invalid username/email or password" }, status: :unauthorized
    end
  end

  def refresh
    payload = JsonWebToken.decode(refresh_params[:refresh_token])

    if payload && payload["type"] == "refresh" && (user = User.find_by(id: payload["user_id"]))
      render json: {
        access_token: JsonWebToken.encode({ user_id: user.id, type: "access" }, ACCESS_TOKEN_TTL.from_now)
      }, status: :ok
    else
      render json: { error: "Invalid refresh token" }, status: :unauthorized
    end
  end

  private

  def login_params
    params.permit(:username, :password)
  end

  def refresh_params
    params.permit(:refresh_token)
  end
end
