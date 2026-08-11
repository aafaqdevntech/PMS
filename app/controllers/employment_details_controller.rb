class EmploymentDetailsController < ApplicationController
  before_action :set_user
  before_action :set_employment_detail, only: [:show, :update, :destroy, :assign_team]

  # GET /users/:user_id/employment_detail  (admin, or the user themself)
  def show
    authorize @employment_detail
    render json: @employment_detail
  end

  # POST /users/:user_id/employment_detail  (admin only)
  def create
    authorize EmploymentDetail

    if @user.employment_detail.present?
      return render json: { errors: ["Employment detail already exists for this user. Use PATCH to update it."] },
                    status: :unprocessable_entity
    end

    detail = @user.build_employment_detail(employment_detail_params)
    detail.save!
    render json: detail, status: :created
  end

  # PATCH/PUT /users/:user_id/employment_detail  (admin only)
  def update
    authorize @employment_detail
    @employment_detail.update!(employment_detail_params)
    render json: @employment_detail
  end

  # DELETE /users/:user_id/employment_detail  (admin only)
  def destroy
    authorize @employment_detail
    @employment_detail.destroy!
    head :no_content
  end

  # PATCH /users/:user_id/employment_detail/assign_team  (admin only)
  # One endpoint for both directions: team_id present assigns that team
  # (404 if it doesn't exist), team_id absent/null unassigns (nils it out).
  def assign_team
    authorize @employment_detail, :update?
    team_id = assign_team_params[:team_id]
    team = team_id.present? ? Team.find(team_id) : nil
    @employment_detail.update!(team_id: team&.id)
    render json: @employment_detail
  end

  private

  def set_user
    @user = User.find(params[:user_id])
  end

  def set_employment_detail
    @employment_detail = @user.employment_detail || raise(ActiveRecord::RecordNotFound)
  end

  def employment_detail_params
    params.permit(:team_id, :role, :job_position, :joined_at)
  end

  def assign_team_params
    params.permit(:team_id)
  end
end
