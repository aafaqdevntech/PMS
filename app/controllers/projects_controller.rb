class ProjectsController < ApplicationController
  before_action :set_project, only: [:show, :update, :destroy, :assign_team, :unassign_team]

  # GET /projects  (admin: all; team member: their own team's projects)
  def index
    authorize Project
    render json: policy_scope(Project)
  end

  # GET /projects/:id  (admin, or a member of the project's team)
  def show
    authorize @project
    render json: @project
  end

  # POST /projects  (admin only). created_by is always the current admin;
  # team_id/start_date are system-controlled and never accepted here.
  def create
    project = Project.new(create_params)
    project.created_by = current_user
    authorize project
    project.save!
    render json: project, status: :created
  end

  # PATCH/PUT /projects/:id  (admin only). team_id is not accepted here —
  # use POST /projects/:id/assign_team or DELETE /projects/:id/unassign_team.
  def update
    authorize @project
    @project.update!(update_params)
    render json: @project
  end

  # DELETE /projects/:id  (admin only)
  def destroy
    authorize @project
    @project.destroy!
    head :no_content
  end

  # POST /projects/:id/assign_team  (admin only)
  def assign_team
    authorize @project, :assign_team?
    team = Team.find_by!("name = ? COLLATE NOCASE", assign_team_params[:team_name])
    @project.update!(team_id: team.id)
    render json: @project
  end

  # DELETE /projects/:id/unassign_team  (admin only). Auto-archives the
  # project (see Project#auto_archive_if_unassigned).
  def unassign_team
    authorize @project, :unassign_team?
    @project.update!(team_id: nil)
    render json: @project
  end

  private

  def set_project
    @project = Project.find(params[:id])
  end

  def create_params
    params.permit(:title, :description)
  end

  def update_params
    params.permit(:title, :description, :status, :end_date)
  end

  def assign_team_params
    params.permit(:team_name)
  end
end
