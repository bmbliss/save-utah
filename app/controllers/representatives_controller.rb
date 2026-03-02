class RepresentativesController < ApplicationController
  def index
    set_meta_tags(
      title: "Utah Representatives",
      description: "Browse all Utah elected officials at the state and federal level. Filter by level, chamber, and party. Contact info and voting records."
    )

    @representatives = Representative.active.alphabetical

    # Apply filters
    @representatives = @representatives.where(level: params[:level]) if params[:level].present?
    @representatives = @representatives.by_chamber(params[:chamber]) if params[:chamber].present?
    @representatives = @representatives.by_party(params[:party]) if params[:party].present?

    # Search by name
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @representatives = @representatives.where("full_name ILIKE ?", search_term)
    end

    @pagy, @representatives = pagy(@representatives)
  end

  def show
    @representative = Representative.friendly.find(params[:id])
    @votes = @representative.votes.recent.includes(:bill).limit(20)
    @action_scripts = @representative.action_scripts.active.ordered

    set_meta_tags(
      title: @representative.display_name,
      description: "#{@representative.display_name} — #{@representative.party} #{@representative.title}. View voting record, contact information, and action scripts."
    )
  end
end
