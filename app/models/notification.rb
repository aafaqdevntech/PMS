class Notification < ApplicationRecord
  belongs_to :recipient, class_name: "User"
  belongs_to :actor, class_name: "User"
  belongs_to :issue

  enum :event_type, { issue_raised: 0, issue_resolved: 1, issue_rejected: 2 }, validate: true

  scope :unread, -> { where(read_at: nil) }

  def read?
    read_at.present?
  end
end
