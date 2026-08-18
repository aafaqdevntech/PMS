class ApplicationController < ActionController::API
  include Pundit::Authorization

  before_action :authenticate_user!

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :record_invalid
  rescue_from ActiveRecord::RecordNotDestroyed, with: :record_invalid

  private

  def authenticate_user!
    render json: { error: "Please log in" }, status: :unauthorized unless current_user
  end
  # ||= assign @current_user only if it's not already set, so we don't hit the database multiple times per request.
  def current_user
    @current_user ||= User.find_by(id: decoded_access_token && decoded_access_token["user_id"])
  end

  def decoded_access_token
    return @decoded_access_token if defined?(@decoded_access_token)

    # logic about only access type  tokens being valid for authentication, not refresh tokens
    payload = JsonWebToken.decode(bearer_token)
    @decoded_access_token = (payload && payload["type"] == "access") ? payload : nil
  end

  def bearer_token
    header = request.headers["Authorization"]
    header&.split(" ")&.last
  end

  # Pundit calls this instead of current_user when building policies, so
  # `authorize`/`policy_scope` see the same authenticated user everywhere.
  def pundit_user
    current_user
  end

  def user_not_authorized
    render json: { error: "You are not authorized to perform this action" }, status: :forbidden
  end

  def record_not_found
    render json: { error: "Record not found" }, status: :not_found
  end

  def record_invalid(exception)
    render json: { errors: exception.record.errors.full_messages }, status: :unprocessable_entity
  end
end
