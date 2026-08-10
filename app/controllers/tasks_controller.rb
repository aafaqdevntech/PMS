class TasksController < ApplicationController
  before_action :set_project, only: [:index, :create]
  before_action :set_task, only: [:show, :update, :destroy, :assign, :unassign, :change_status]

  # GET /projects/:project_id/tasks  (admin, or a member of the project's team)
  def index
    authorize @project, :show?
    render json: policy_scope(Task).where(project: @project)
  end

  # POST /projects/:project_id/tasks  (the project team's lead only).
  # created_by is always the current user; a task always starts unassigned.
  def create
    task = @project.tasks.build(create_params)
    task.created_by = current_user
    authorize task
    task.save!
    render json: task, status: :created
  end

  # GET /tasks/:id  (admin, or a member of the project's team)
  def show
    authorize @task
    render json: @task
  end

  # PATCH/PUT /tasks/:id  (the project team's lead only). status and
  # assigned_to_id are not editable here — see assign/unassign/status.
  def update
    authorize @task
    @task.update!(update_params)
    render json: @task
  end

  # DELETE /tasks/:id  (the project team's lead only)
  def destroy
    authorize @task
    @task.destroy!
    head :no_content
  end

  # POST /tasks/:id/assign  (the project team's lead only). Assigns or
  # reassigns, and the lead picks whether work starts now or is parked.
  def assign
    authorize @task, :assign?
    status = assign_params[:status].presence || "assigned"
    unless Task::ASSIGNABLE_STATUSES.include?(status)
      return render json: { errors: ["Status must be one of: #{Task::ASSIGNABLE_STATUSES.join(', ')}"] },
                    status: :unprocessable_entity
    end

    @task.update!(assigned_to_id: assign_params[:assigned_to_id], status: status)
    render json: @task
  end

  # DELETE /tasks/:id/unassign  (the project team's lead only). Clears the
  # assignee and returns the task to the unassigned pool.
  def unassign
    authorize @task, :unassign?
    @task.update!(assigned_to_id: nil, status: :unassigned)
    render json: @task
  end

  # PATCH /tasks/:id/status  (the lead, or the assignee — each with their own
  # legal moves, see Task::LEAD_TRANSITIONS / Task::ASSIGNEE_TRANSITIONS)
  def change_status
    authorize @task, :change_status?
    @task.status_changed_by = current_user
    @task.update!(status_params)
    render json: @task
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  end

  def set_task
    @task = Task.find(params[:id])
  end

  def create_params
    params.permit(:title, :description, :priority, :due_date, :issue_id)
  end

  def update_params
    params.permit(:title, :description, :priority, :due_date, :issue_id)
  end

  def assign_params
    params.permit(:assigned_to_id, :status)
  end

  def status_params
    params.permit(:status)
  end
end
