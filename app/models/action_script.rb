class ActionScript < ApplicationRecord
  # --- Enums ---
  enum :action_type, { call: 0, email: 1 }

  # --- Associations ---
  belongs_to :representative, optional: true
  belongs_to :bill, optional: true

  # --- Validations ---
  validates :title, presence: true
  validates :script_template, presence: true
  validates :action_type, presence: true

  # --- Scopes ---
  scope :active, -> { where(active: true) }
  scope :featured, -> { where(featured: true) }
  scope :calls, -> { where(action_type: :call) }
  scope :emails, -> { where(action_type: :email) }
  scope :ordered, -> { order(:sort_order, :title) }

  # Renders the script template with actual representative data
  # Replaces [REP_NAME], [REP_PHONE], [REP_TITLE], [BILL_NUMBER], etc.
  def render_script(representative: nil, bill: nil)
    rep = representative || self.representative
    b = bill || self.bill

    text = script_template.dup
    if rep
      text.gsub!("[REP_NAME]", rep.full_name.to_s)
      text.gsub!("[REP_PHONE]", rep.phone.to_s)
      text.gsub!("[REP_TITLE]", rep.title.to_s)
      text.gsub!("[REP_EMAIL]", rep.email.to_s)
    end
    if b
      text.gsub!("[BILL_NUMBER]", b.bill_number.to_s)
      text.gsub!("[BILL_TITLE]", b.title.to_s)
    end
    text
  end
end
