class IssueBill < ApplicationRecord
  # --- Enums ---
  enum :popular_position, { yes: 0, no: 1 }

  # --- Associations ---
  belongs_to :issue
  belongs_to :bill

  # --- Validations ---
  validates :issue_id, uniqueness: { scope: :bill_id, message: "already linked to this bill" }
  validates :popular_position, presence: true

  # --- Scopes ---
  scope :ordered, -> { order(:sort_order) }

  # Display-friendly label for the popular position ("Vote YES" / "Vote NO")
  def popular_position_label
    yes? ? "Vote YES" : "Vote NO"
  end
end
