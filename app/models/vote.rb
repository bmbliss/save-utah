class Vote < ApplicationRecord
  # --- Enums ---
  enum :position, {
    yes: 0,
    no: 1,
    abstain: 2,
    not_voting: 3,
    present: 4
  }

  # --- Associations ---
  belongs_to :representative
  belongs_to :bill

  # --- Validations ---
  validates :position, presence: true
  validates :representative_id, uniqueness: { scope: :bill_id, message: "has already voted on this bill" }

  # --- Scopes ---
  scope :recent, -> { order(voted_on: :desc) }
  scope :yes_votes, -> { where(position: :yes) }
  scope :no_votes, -> { where(position: :no) }

  # Display-friendly position label
  def position_label
    case position
    when "yes" then "Yea"
    when "no" then "Nay"
    when "abstain" then "Abstain"
    when "not_voting" then "Not Voting"
    when "present" then "Present"
    end
  end

  # CSS class for color-coding votes
  def position_css_class
    case position
    when "yes" then "text-green-700 bg-green-100"
    when "no" then "text-red-700 bg-red-100"
    when "abstain", "not_voting", "present" then "text-gray-600 bg-gray-100"
    end
  end
end
