class FeaturedItem < ApplicationRecord
  # --- Enums ---
  enum :section, { hero: 0, spotlight: 1, recent_actions: 2 }

  # --- Associations ---
  belongs_to :featurable, polymorphic: true

  # --- Validations ---
  validates :headline, presence: true
  validates :section, presence: true

  # --- Scopes ---
  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:sort_order) }
  scope :heroes, -> { where(section: :hero).active.ordered }
  scope :spotlights, -> { where(section: :spotlight).active.ordered }
  scope :recent, -> { where(section: :recent_actions).active.ordered }
end
