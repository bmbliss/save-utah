class PagesController < ApplicationController
  def home
    # Load the hot issue for the blast (fall back to first active issue)
    @hot_issue = Issue.hot.first || Issue.active.ordered.first

    if @hot_issue
      # Load issue bills and build votes lookup for O(1) score computation
      @issue_bills = @hot_issue.issue_bills.ordered.includes(:bill)
      bill_ids = @issue_bills.map(&:bill_id)
      all_votes = Vote.where(bill_id: bill_ids).includes(:representative, :bill)
      @votes_lookup = all_votes.index_by { |v| [v.representative_id, v.bill_id] }

      # Get offending reps (those who voted on these bills)
      rep_ids = all_votes.map(&:representative_id).uniq
      @representatives = Representative.where(id: rep_ids).includes(:votes)

      # Pre-compute scores, sort worst-first
      @scores = {}
      @representatives.each do |rep|
        @scores[rep.id] = @hot_issue.accountability_score(rep, votes_lookup: @votes_lookup)
      end

      @representatives = @representatives.sort_by do |rep|
        score = @scores[rep.id][:score]
        score.nil? ? 999 : score
      end

      # Load action scripts for the blast
      @call_script = ActionScript.active.calls.where(bill_id: bill_ids).first
      @text_script = ActionScript.active.texts.where(bill_id: bill_ids).first
      @email_script = ActionScript.active.emails.where(bill_id: bill_ids).first
    end

    # Other issues for below-the-fold section
    @other_issues = Issue.active.ordered.where.not(id: @hot_issue&.id).limit(4)

    # Dynamic OG meta tags from the hot issue (falls back to name/description)
    og_title = @hot_issue&.og_title.presence || @hot_issue&.name || "Save Utah"
    og_desc = @hot_issue&.og_description.presence || @hot_issue&.description&.truncate(200) || "Hold your representatives accountable."

    set_meta_tags(
      title: og_title,
      description: og_desc,
      og: {
        title: og_title,
        description: og_desc,
        type: "website"
      },
      twitter: {
        card: "summary_large_image",
        title: og_title,
        description: og_desc
      }
    )
  end

  def about
    set_meta_tags(
      title: "About",
      description: "Save Utah is a nonpartisan civic engagement platform tracking Utah elected officials and their voting records. Open data, plain language summaries, and action scripts."
    )
  end
end
