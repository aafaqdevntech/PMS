class User < ApplicationRecord
  has_secure_password

  has_one :profile, dependent: :destroy
  has_one :employment_detail, dependent: :destroy
  has_one :led_team, class_name: "Team", foreign_key: :team_lead_id, inverse_of: :team_lead, dependent: :nullify

  # Deleting an assignee leaves their tasks in place for the lead to hand on;
  # created_by can't be nullified (it's required), so a lead who still owns
  # tasks can't be deleted until those tasks are.
  has_many :assigned_tasks, class_name: "Task", foreign_key: :assigned_to_id,
                            inverse_of: :assigned_to, dependent: :nullify
  has_many :created_tasks, class_name: "Task", foreign_key: :created_by_id,
                           inverse_of: :created_by, dependent: :restrict_with_error

  # A user who raised an issue can't be deleted until the issue is (raised_by_id
  # is required), mirroring created_tasks above.
  has_many :raised_issues, class_name: "Issue", foreign_key: :raised_by_id,
                           inverse_of: :raised_by, dependent: :restrict_with_error

  # comments.user_id is NOT NULL, so a deleted user's comments go with them.
  has_many :comments, dependent: :destroy
  has_many :refresh_tokens, dependent: :destroy

  validates :username, presence: true, uniqueness: { case_sensitive: false }
  validates :email, presence: true, uniqueness: { case_sensitive: false },
                     format: { with: URI::MailTo::EMAIL_REGEXP }

  # Role lives on EmploymentDetail (admin / team_lead / member), not on the user directly.
  def admin?
    employment_detail&.admin? || false
  end

  def generate_password_reset_token!
    raw_token = SecureRandom.urlsafe_base64(32)
    update!(reset_password_token: self.class.digest_token(raw_token), reset_password_sent_at: Time.current)
    raw_token
  end

  def password_reset_token_valid?
    reset_password_sent_at.present? && reset_password_sent_at > 2.hours.ago
  end

  def clear_password_reset_token!
    update!(reset_password_token: nil, reset_password_sent_at: nil)
  end

  def self.find_by_reset_token(raw_token)
    return nil if raw_token.blank?

    find_by(reset_password_token: digest_token(raw_token))
  end

  def self.digest_token(raw_token)
    Digest::SHA256.hexdigest(raw_token)
  end
end
