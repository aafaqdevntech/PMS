class ProfilesController < ApplicationController
  before_action :set_user

  # GET /users/:user_id/profile  (admin, or the user themself)
  def show
    profile = @user.profile || raise(ActiveRecord::RecordNotFound)
    authorize profile
    render json: profile
  end

  # POST /users/:user_id/profile  (admin only)
  def create
    authorize Profile

    if @user.profile.present?
      return render json: { errors: ["Profile already exists for this user. Use PATCH to update it."] },
                    status: :unprocessable_entity
    end

    profile = @user.build_profile(profile_params)
    profile.save!
    render json: profile, status: :created
  end

  # PATCH/PUT /users/:user_id/profile  (admin only)
  def update
    profile = @user.profile || raise(ActiveRecord::RecordNotFound)
    authorize profile
    profile.update!(profile_params)
    render json: profile
  end

  # DELETE /users/:user_id/profile  (admin only)
  def destroy
    profile = @user.profile || raise(ActiveRecord::RecordNotFound)
    authorize profile
    profile.destroy!
    head :no_content
  end

  private

  def set_user
    @user = User.find(params[:user_id])
  end

  def profile_params
    params.permit(:full_name, :phone, :address, :city, :country, :image_url)
  end
end
