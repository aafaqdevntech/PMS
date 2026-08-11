class TeamsController < ApplicationController
  before_action :set_team, only: [:show, :update, :destroy]

  # GET /teams  (admin only)
  def index
    authorize Team
    render json: policy_scope(Team), each_serializer: TeamSummarySerializer
  end

  # GET /teams/:id  (any authenticated user)
  def show
    authorize @team
    render json: @team, serializer: TeamSummarySerializer
  end

  # POST /teams  (admin only)
  def create
    team = Team.new(team_params)
    authorize team
    team.save!
    render json: team, status: :created
  end

  # PATCH/PUT /teams/:id  (admin only)
  def update
    authorize @team
    @team.update!(team_params)
    render json: @team
  end

  # DELETE /teams/:id  (admin only)
  def destroy
    authorize @team
    @team.destroy!
    head :no_content
  end

  # PATCH /teams/assign_lead  (admin only)
  # team_id (body) identifies the team. username present assigns that user
  # as lead (they must already hold the team_lead role) and cascades
  # employment_detail.team_id to this team too; absent/blank unassigns the
  # current lead, cascading their employment_detail.team_id back to null.
  def assign_lead
    team = Team.find(team_username_params[:team_id])
    authorize team, :update?

    username = team_username_params[:username]
    if username.present?
      user = User.find_by!(username: username)
      detail = user.employment_detail || raise(ActiveRecord::RecordNotFound)
      unless detail.team_lead?
        return render json: { errors: ["User cannot be made team lead. Promote them to the team_lead role first."] },
                      status: :unprocessable_entity
      end
      TeamLeadAssignment.assign(team: team, user: user)
    else
      TeamLeadAssignment.unassign(team: team)
    end

    render json: team.reload, serializer: TeamSummarySerializer
  end

  # PATCH /teams/assign_member  (admin only)
  # team_id + username (both body) — the user must already hold the member
  # role. Sets employment_detail.team_id to this team, reassigning freely
  # even if they already belong to a different one.
  def assign_member
    team = Team.find(team_username_params[:team_id])
    authorize team, :update?

    user = User.find_by!(username: team_username_params[:username])
    detail = user.employment_detail || raise(ActiveRecord::RecordNotFound)
    unless detail.member?
      return render json: { errors: ["User cannot be added as a member. Their role must be member."] },
                    status: :unprocessable_entity
    end

    detail.update!(team_id: team.id)
    render json: detail
  end

  # PATCH /teams/unassign_member  (admin only)
  # team_id + username (both body) — team_id must match the user's current
  # employment_detail.team_id, which is then set to null.
  def unassign_member
    team = Team.find(team_username_params[:team_id])
    authorize team, :update?

    user = User.find_by!(username: team_username_params[:username])
    detail = user.employment_detail || raise(ActiveRecord::RecordNotFound)
    unless detail.team_id == team.id
      return render json: { errors: ["User is not a member of this team."] }, status: :unprocessable_entity
    end

    detail.update!(team_id: nil)
    render json: detail
  end

  private

  def set_team
    @team = Team.find(params[:id])
  end

  def team_params
    params.permit(:name, :description, :team_lead_id)
  end

  def team_username_params
    params.permit(:team_id, :username)
  end
end
