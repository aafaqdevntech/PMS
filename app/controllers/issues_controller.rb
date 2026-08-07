class IssuesController < ApplicationController
  before_action :set_project, only: [:index, :create]
  before_action :set_issue, only: [:show, :update, :destroy, :resolve, :reject]

  # GET /projects/:project_id/issues  (admin, or a member of the project's team)
  def index
    authorize @project, :show?
    render json: policy_scope(Issue).where(project: @project)
  end

  # POST /projects/:project_id/issues  (team members only — not admins).
  # raised_by is always the current user; status always starts open.
  def create
    issue = @project.issues.build(create_params)
    issue.raised_by = current_user
    authorize issue
    issue.save!
    render json: issue, status: :created
  end

  # GET /issues/:id  (admin, or a member of the project's team)
  def show
    authorize @issue
    render json: @issue
  end

  # PATCH/PUT /issues/:id  (the member who raised it, while still open).
  # status and resolution_note are not editable here — see resolve/reject.
  def update
    authorize @issue
    @issue.update!(update_params)
    render json: @issue
  end

  # DELETE /issues/:id  (the member who raised it, while still open)
  def destroy
    authorize @issue
    @issue.destroy!
    head :no_content
  end

  # POST /issues/:id/resolve  (the project team's lead only, while open)
  def resolve
    authorize @issue
    close_issue(:resolved)
  end

  # POST /issues/:id/reject  (the project team's lead only, while open)
  def reject
    authorize @issue
    close_issue(:rejected)
  end

  private

  def close_issue(status)
    @issue.update!(status: status, resolution_note: note_params[:resolution_note])
    render json: @issue
  end

  def set_project
    @project = Project.find(params[:project_id])
  end

  def set_issue
    @issue = Issue.find(params[:id])
  end

  def create_params
    params.permit(:title, :description)
  end

  def update_params
    params.permit(:title, :description)
  end

  def note_params
    params.permit(:resolution_note)
  end
end
