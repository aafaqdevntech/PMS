class NotificationsController < ApplicationController
  before_action :set_notification, only: [:read]

  # GET /notifications  (any authenticated user — their own feed, newest first)
  def index
    authorize Notification
    render json: policy_scope(Notification).order(created_at: :desc)
  end

  # PATCH /notifications/:id/read  (the recipient only)
  def read
    authorize @notification
    @notification.update!(read_at: Time.current) if @notification.read_at.nil?
    render json: @notification
  end

  # PATCH /notifications/read_all  (marks every one of the caller's own
  # unread notifications read; scoped by policy_scope, never a client-
  # supplied id, so there's nothing to authorize per-record)
  def read_all
    authorize Notification
    policy_scope(Notification).unread.update_all(read_at: Time.current)
    head :no_content
  end

  private

  def set_notification
    @notification = Notification.find(params[:id])
  end
end
