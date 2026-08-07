class UsersController < ApplicationController
  before_action :set_user, only: [:show, :update, :destroy]

  # GET /users  (admin: everyone; team member: their own team roster, limited fields)
  def index
    authorize User
    users = policy_scope(User)
    if current_user.admin?
      render json: users
    else
      render json: users, each_serializer: TeammateSerializer
    end
  end

  # GET /users/:id  (admin, the user themself, or a teammate — teammates get limited fields)
  def show
    authorize @user
    if current_user.admin? || @user == current_user
      render json: @user
    else
      render json: @user, serializer: TeammateSerializer
    end
  end

  # POST /users  (admin only — this is how accounts get created; there is no
  # public sign-up)
  def create
    user = User.new(user_params)
    authorize user
    user.save!
    render json: user, status: :created
  end

  # PATCH/PUT /users/:id  (admin only — a regular user changes their own
  # password only, via the forgot-password flow, not through this endpoint)
  def update
    authorize @user
    @user.update!(user_params)
    render json: @user
  end

  # DELETE /users/:id  (admin only)
  def destroy
    authorize @user
    @user.destroy!
    head :no_content
  end

  # GET /me  (any authenticated user — their own record)
  def me
    render json: current_user
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.permit(:username, :email, :password, :password_confirmation)
  end
end
