class Profile < ApplicationRecord
  belongs_to :user

  validates :user_id, uniqueness: true
  validates :full_name, presence: true
end
