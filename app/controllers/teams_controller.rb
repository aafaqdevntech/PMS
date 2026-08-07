class TeamsController < ApplicationController
  before_action :set_team, only: [:show, :update, :destroy]

  # GET /teams  (any authenticated user)
  def index
    authorize Team
    render json: policy_scope(Team)
  end

  # GET /teams/:id  (any authenticated user)
  def show
    authorize @team
    render json: @team
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

  private

  def set_team
    @team = Team.find(params[:id])
  end

  def team_params
    params.permit(:name, :description, :team_lead_id)
  end
end
