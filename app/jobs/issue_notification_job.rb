class IssueNotificationJob < ApplicationJob
  queue_as :default

  # If the issue or actor was deleted between enqueue and execution, there's
  # nothing left to notify about — drop it instead of retrying forever.
  discard_on ActiveRecord::RecordNotFound

  def perform(issue_id:, actor_id:, event_type:)
    IssueNotifier.notify(issue: Issue.find(issue_id), actor: User.find(actor_id), event_type: event_type)
  end
end
