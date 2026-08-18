class IssueNotifier
  def self.notify(issue:, actor:, event_type:)
    new(issue: issue, actor: actor, event_type: event_type).call
  end

  def initialize(issue:, actor:, event_type:)
    @issue = issue
    @actor = actor
    @event_type = event_type
  end

  def call
    recipients.find_each do |recipient|
      notification = Notification.create!(recipient: recipient, actor: actor, issue: issue, event_type: event_type)
      broadcast(notification)
    end
  end

  private

  attr_reader :issue, :actor, :event_type

  # "The team" is resolved the same way IssuePolicy resolves it, via the
  # project's team, never via employment_detail.role. Every other member
  # gets notified, not just the lead or just the raiser.
  def recipients
    team = issue.project.team
    return User.none unless team

    team.users.where.not(id: actor.id)
  end

  def broadcast(notification)
    payload = ActiveModelSerializers::SerializableResource.new(notification, serializer: NotificationSerializer).as_json
    NotificationsChannel.broadcast_to(notification.recipient, payload)
  end
end
