class Representative < ApplicationRecord
  extend FriendlyId
  friendly_id :full_name, use: :slugged

  # --- Enums ---
  enum :position_type, {
    us_senator: 0,
    us_representative: 1,
    state_senator: 2,
    state_representative: 3,
    governor: 4,
    lt_governor: 5,
    attorney_general: 6,
    state_auditor: 7,
    state_treasurer: 8
  }

  enum :level, { federal: 0, state: 1 }, prefix: true

  # --- Associations ---
  has_many :votes, dependent: :destroy
  has_many :bills, through: :votes
  has_many :action_scripts, dependent: :nullify
  has_many :featured_items, as: :featurable, dependent: :destroy

  # --- Validations ---
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :full_name, presence: true
  validates :position_type, presence: true
  validates :level, presence: true
  validates :party, presence: true

  # --- Scopes ---
  scope :active, -> { where(active: true) }
  scope :federal, -> { where(level: :federal) }
  scope :state_level, -> { where(level: :state) }
  scope :senators, -> { where(position_type: [:us_senator, :state_senator]) }
  scope :representatives, -> { where(position_type: [:us_representative, :state_representative]) }
  scope :executives, -> { where(position_type: [:governor, :lt_governor, :attorney_general, :state_auditor, :state_treasurer]) }
  scope :by_chamber, ->(chamber) { where(chamber: chamber) }
  scope :by_party, ->(party) { where(party: party) }
  scope :alphabetical, -> { order(:last_name, :first_name) }

  # --- Callbacks ---
  before_validation :set_full_name, if: -> { full_name.blank? && first_name.present? && last_name.present? }

  # Returns display-friendly title + name (e.g., "Governor Spencer Cox")
  def display_name
    [title, full_name].compact_blank.join(" ")
  end

  # Returns the party abbreviation (R, D, I, etc.)
  def party_abbrev
    case party&.downcase
    when "republican" then "R"
    when "democrat", "democratic" then "D"
    when "independent" then "I"
    when "libertarian" then "L"
    else party&.first&.upcase
    end
  end

  # Returns a formatted label like "Sen. Mike Lee (R)"
  def short_label
    prefix = case position_type
    when "us_senator" then "Sen."
    when "us_representative" then "Rep."
    when "state_senator" then "Sen."
    when "state_representative" then "Rep."
    when "governor" then "Gov."
    when "lt_governor" then "Lt. Gov."
    when "attorney_general" then "AG"
    when "state_auditor" then "Auditor"
    when "state_treasurer" then "Treasurer"
    end
    "#{prefix} #{full_name} (#{party_abbrev})"
  end

  # Returns an array of { label:, number: } hashes for all non-blank phone fields
  def phone_numbers
    numbers = []
    numbers << { label: "Office", number: phone } if phone.present?
    numbers << { label: "Mobile", number: phone_mobile } if phone_mobile.present?
    numbers << { label: "Work", number: phone_work } if phone_work.present?
    numbers << { label: "Home", number: phone_home } if phone_home.present?
    numbers
  end

  private

  def set_full_name
    self.full_name = "#{first_name} #{last_name}"
  end
end
