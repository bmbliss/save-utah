class IssuesController < ApplicationController
  def index
    set_meta_tags(
      title: "The Issues That Matter",
      description: "Hot-button policy issues in Utah — accountability scorecards showing which representatives stand with the people and who sold them out."
    )

    @issues = Issue.active.ordered
  end

  def show
    @issue = Issue.friendly.find(params[:id])
    @issue_bills = @issue.issue_bills.ordered.includes(:bill)

    set_meta_tags(
      title: "#{@issue.name} — Accountability Scorecard",
      description: @issue.description&.truncate(160)
    )

    # Build votes lookup hash: { [rep_id, bill_id] => vote } — one query, O(1) lookups in view
    bill_ids = @issue_bills.map(&:bill_id)
    all_votes = Vote.where(bill_id: bill_ids).includes(:representative, :bill)
    @votes_lookup = all_votes.index_by { |v| [v.representative_id, v.bill_id] }

    # Get all reps who have voted on any of these bills
    rep_ids = all_votes.map(&:representative_id).uniq
    @representatives = Representative.where(id: rep_ids).includes(:votes)

    # Pre-compute scores for each rep, then sort worst-first
    @scores = {}
    @representatives.each do |rep|
      @scores[rep.id] = @issue.accountability_score(rep, votes_lookup: @votes_lookup)
    end

    # Sort: reps with lowest score first (worst offenders), nil scores last
    @representatives = @representatives.sort_by do |rep|
      score = @scores[rep.id][:score]
      score.nil? ? 999 : score
    end

    # Related action scripts
    @action_scripts = ActionScript.active.ordered.where(bill_id: bill_ids).includes(:representative, :bill).limit(4)
  end
end
