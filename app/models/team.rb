class Team < ApplicationRecord
  belongs_to :team_lead, class_name: "User", optional: true

  has_many :employment_details, dependent: :restrict_with_error
  has_many :users, through: :employment_details
  has_many :projects, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :team_lead_id, uniqueness: true, allow_nil: true
end
