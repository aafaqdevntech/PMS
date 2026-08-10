class CommentsController < ApplicationController
  # Only these two can be commented on, and the class is looked up from this
  # table rather than constantized from the path.
  COMMENTABLES = { "issue_id" => Issue, "task_id" => Task }.freeze

  before_action :set_commentable, only: [:index, :create]
  before_action :set_comment, only: [:update, :destroy]

  # GET /issues/:issue_id/comments, GET /tasks/:task_id/comments
  # (admin, or a member of the Issue/Task's team)
  def index
    authorize @commentable, :show?
    render json: policy_scope(Comment).where(commentable: @commentable).order(:created_at)
  end

  # POST /issues/:issue_id/comments, POST /tasks/:task_id/comments
  # (members of the Issue/Task's team — not admins). user is always the
  # current user, and the parent always comes from the path.
  def create
    comment = @commentable.comments.build(comment_params)
    comment.user = current_user
    authorize comment
    comment.save!
    render json: comment, status: :created
  end

  # PATCH/PUT /comments/:id  (the author only)
  def update
    authorize @comment
    @comment.update!(comment_params)
    render json: @comment
  end

  # DELETE /comments/:id  (the author, or an admin)
  def destroy
    authorize @comment
    @comment.destroy!
    head :no_content
  end

  private

  def set_commentable
    key = COMMENTABLES.keys.find { |k| params[k].present? }
    raise ActiveRecord::RecordNotFound if key.nil?

    @commentable = COMMENTABLES.fetch(key).find(params[key])
  end

  def set_comment
    @comment = Comment.find(params[:id])
  end

  def comment_params
    params.permit(:body)
  end
end
