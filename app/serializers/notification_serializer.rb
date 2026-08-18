class NotificationSerializer < ActiveModel::Serializer
  attributes :id, :issue_id, :actor_id, :actor_name, :event_type, :message, :read, :created_at

  def actor_name
    object.actor&.profile&.full_name
  end

  def message
    title = object.issue&.title
    case object.event_type
    when "issue_raised"   then "#{actor_name || 'Someone'} raised a new issue: #{title}"
    when "issue_resolved" then "#{actor_name || 'The team lead'} resolved: #{title}"
    when "issue_rejected" then "#{actor_name || 'The team lead'} rejected: #{title}"
    end
  end

  def read
    object.read_at.present?
  end
end
