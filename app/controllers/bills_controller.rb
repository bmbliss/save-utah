class BillsController < ApplicationController
  def index
    set_meta_tags(
      title: "Bills & Votes",
      description: "Track legislation affecting Utah at the state and federal level. See vote breakdowns, editorial summaries, and how your representatives voted."
    )

    @bills = Bill.recent

    # Apply filters
    @bills = @bills.where(level: params[:level]) if params[:level].present?
    @bills = @bills.by_session(params[:year]) if params[:year].present?
    @bills = @bills.by_status(params[:status]) if params[:status].present?
    @bills = @bills.by_chamber(params[:chamber]) if params[:chamber].present?

    # Search by title or bill number
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @bills = @bills.where("title ILIKE ? OR bill_number ILIKE ?", search_term, search_term)
    end

    @pagy, @bills = pagy(@bills)
  end

  def show
    @bill = Bill.friendly.find(params[:id])
    @votes = @bill.votes.includes(:representative).order("representatives.last_name")
    @vote_summary = @bill.vote_summary
    @action_scripts = @bill.action_scripts.active.ordered

    set_meta_tags(
      title: "#{@bill.bill_number}: #{@bill.title}",
      description: @bill.editorial_summary.presence || @bill.summary.presence || "View vote breakdown and details for #{@bill.bill_number}."
    )
  end
end
