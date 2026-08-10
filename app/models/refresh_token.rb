class RefreshToken < ApplicationRecord
  belongs_to :user

  validates :jti, presence: true, uniqueness: true
  validates :expires_at, presence: true

  def revoked?
    revoked_at.present?
  end

  def expired?
    expires_at.present? && expires_at < Time.current
  end
end
