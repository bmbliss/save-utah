class Bill < ApplicationRecord
  extend FriendlyId
  friendly_id :bill_number_and_title, use: :slugged

  # --- Enums ---
  enum :level, { federal: 0, state: 1 }, prefix: true

  # --- Associations ---
  has_many :votes, dependent: :destroy
  has_many :representatives, through: :votes
  has_many :action_scripts, dependent: :nullify
  has_many :featured_items, as: :featurable, dependent: :destroy

  # --- Validations ---
  validates :title, presence: true
  validates :bill_number, presence: true
  validates :level, presence: true

  # --- Scopes ---
  scope :federal, -> { where(level: :federal) }
  scope :state_level, -> { where(level: :state) }
  scope :featured, -> { where(featured: true) }
  scope :by_session, ->(year) { where(session_year: year) }
  scope :by_status, ->(status) { where(status: status) }
  scope :by_chamber, ->(chamber) { where(chamber: chamber) }
  scope :recent, -> { order(last_action_on: :desc) }
  scope :with_votes, -> { joins(:votes).distinct }

  # Vote counts for this bill
  def vote_summary
    {
      yes: votes.where(position: :yes).count,
      no: votes.where(position: :no).count,
      abstain: votes.where(position: :abstain).count,
      not_voting: votes.where(position: :not_voting).count
    }
  end

  # Returns true if the bill has an editorial summary explaining why it matters
  def has_editorial?
    editorial_summary.present?
  end

  private

  # Generates a slug like "hr-1234-protect-public-lands-act"
  def bill_number_and_title
    [bill_number, title].compact_blank.join(" ")
  end
end
