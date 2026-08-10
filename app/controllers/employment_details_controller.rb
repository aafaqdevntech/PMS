class EmploymentDetailsController < ApplicationController
  before_action :set_user

  # GET /users/:user_id/employment_detail  (admin, or the user themself)
  def show
    detail = @user.employment_detail || raise(ActiveRecord::RecordNotFound)
    authorize detail
    render json: detail
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
    detail = @user.employment_detail || raise(ActiveRecord::RecordNotFound)
    authorize detail
    detail.update!(employment_detail_params)
    render json: detail
  end

  # DELETE /users/:user_id/employment_detail  (admin only)
  def destroy
    detail = @user.employment_detail || raise(ActiveRecord::RecordNotFound)
    authorize detail
    detail.destroy!
    head :no_content
  end

  private

  def set_user
    @user = User.find(params[:user_id])
  end

  def employment_detail_params
    params.permit(:team_id, :role, :job_position, :joined_at)
  end
end
