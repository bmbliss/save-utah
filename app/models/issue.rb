class Issue < ApplicationRecord
  extend FriendlyId
  friendly_id :name, use: :slugged

  # --- Associations ---
  has_many :issue_bills, dependent: :destroy
  has_many :bills, through: :issue_bills

  # --- Validations ---
  validates :name, presence: true, uniqueness: true
  validates :stance_label, presence: true
  validates :against_label, presence: true

  # --- Scopes ---
  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:sort_order, :name) }

  # Computes accountability score for a representative across all bills in this issue.
  # Returns a hash: { aligned:, against:, no_vote:, total:, score: }
  #
  # @param representative [Representative] the rep to score
  # @param votes_lookup [Hash] optional pre-built { [rep_id, bill_id] => vote } hash for O(1) lookups
  def accountability_score(representative, votes_lookup: nil)
    bills_list = issue_bills.includes(:bill)
    total = bills_list.size
    return { aligned: 0, against: 0, no_vote: 0, total: 0, score: nil } if total.zero?

    aligned = 0
    against = 0
    no_vote = 0

    bills_list.each do |ib|
      vote = if votes_lookup
        votes_lookup[[representative.id, ib.bill_id]]
      else
        Vote.find_by(representative: representative, bill: ib.bill)
      end

      if vote.nil?
        no_vote += 1
      elsif vote_aligned?(vote, ib)
        aligned += 1
      else
        against += 1
      end
    end

    # Score is percentage of voted bills that aligned (no_vote excluded from denominator)
    voted = aligned + against
    score = voted.positive? ? ((aligned.to_f / voted) * 100).round : nil

    { aligned: aligned, against: against, no_vote: no_vote, total: total, score: score }
  end

  # Returns CSS classes for a vote cell based on alignment with popular position.
  # Green = aligned with the people, Red = against, Gray = no vote
  def vote_alignment_css(vote, issue_bill)
    if vote.nil?
      "bg-gray-100 text-gray-400"
    elsif vote_aligned?(vote, issue_bill)
      "bg-green-100 text-green-800"
    else
      "bg-red-100 text-red-800"
    end
  end

  # Returns a label for the vote cell — either the stance label or against label
  def vote_alignment_label(vote, issue_bill)
    if vote.nil?
      "No Vote"
    elsif vote_aligned?(vote, issue_bill)
      stance_label
    else
      against_label
    end
  end

  private

  # Checks if a vote aligns with the popular position for the issue bill.
  # If popular_position is "yes", a "yes" vote is aligned.
  # If popular_position is "no", a "no" vote is aligned.
  def vote_aligned?(vote, issue_bill)
    (issue_bill.yes? && vote.yes?) || (issue_bill.no? && vote.no?)
  end
end
