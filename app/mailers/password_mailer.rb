class PasswordMailer < ApplicationMailer
  def reset_instructions(user, raw_token)
    @user = user
    @raw_token = raw_token
    @reset_url = "#{frontend_base_url}/reset-password?token=#{raw_token}"

    mail(to: @user.email, subject: "Reset your password")
  end

  private

  def frontend_base_url
    ENV.fetch("FRONTEND_BASE_URL", "http://localhost:3000")
  end
end
