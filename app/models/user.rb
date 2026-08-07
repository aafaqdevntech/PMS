class User < ApplicationRecord
  has_secure_password

  has_one :profile, dependent: :destroy
  has_one :employment_detail, dependent: :destroy
  has_one :led_team, class_name: "Team", foreign_key: :team_lead_id, inverse_of: :team_lead, dependent: :nullify

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
