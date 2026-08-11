class UsersController < ApplicationController
  before_action :set_user, only: [ :show, :update, :destroy ]

  # GET /users  (admin: everyone; team member: their own team roster)
  # Same flat directory shape for every caller — see UserDirectorySerializer.
  def index
    authorize User
    render json: policy_scope(User), each_serializer: UserDirectorySerializer
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
    render json: {
        user: UserSerializer.new(current_user)
      }, status: :ok
  end

  # GET /me/counts  (any authenticated user — a role-scoped dashboard summary)
  # admin: teams/projects/tasks/issues across the whole company.
  # team lead (teams.team_lead_id): projects/tasks/issues/team_members within their team.
  # member: their own assigned tasks, raised issues, tasks due today, and their team's headcount.
  # No separate authorization check needed — the counts are always scoped to
  # current_user, which is derived from the token server-side, never from the
  # request. Every count is 0 rather than an error when nothing applies.
  def counts
    render json: DashboardCounts.for(current_user)
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.permit(:username, :email, :password, :password_confirmation)
  end
end
