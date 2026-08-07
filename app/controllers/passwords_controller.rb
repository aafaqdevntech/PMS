class PasswordsController < ApplicationController
  skip_before_action :authenticate_user!

  # POST /password/forgot  { email }
  # Always responds the same way, whether or not the email is registered, so
  # this endpoint can't be used to enumerate accounts.
  def create
    user = User.find_by(email: forgot_params[:email])

    if user
      raw_token = user.generate_password_reset_token!
      PasswordMailer.reset_instructions(user, raw_token).deliver_later
    end

    render json: { message: "If that email is registered, password reset instructions have been sent." }
  end

  # PATCH /password/reset  { token, password, password_confirmation }
  def update
    user = User.find_by_reset_token(reset_params[:token])

    if user.nil? || !user.password_reset_token_valid?
      return render json: { error: "That reset link is invalid or has expired." }, status: :unprocessable_entity
    end

    user.password = reset_params[:password]
    user.password_confirmation = reset_params[:password_confirmation]

    if user.save
      user.clear_password_reset_token!
      render json: { message: "Password has been reset. You can now log in." }
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def forgot_params
    params.permit(:email)
  end

  def reset_params
    params.permit(:token, :password, :password_confirmation)
  end
end
