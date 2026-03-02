class PagesController < ApplicationController
  def home
    set_meta_tags(
      title: "Hold Utah's Leaders Accountable",
      description: "Track Utah elected officials, their voting records on bills that matter, and take action. Call scripts, contact info, and vote breakdowns for every representative.",
      keywords: "Utah, representatives, voting records, bills, civic engagement, government transparency"
    )

    # Hero featured items
    @hero_items = FeaturedItem.heroes.includes(:featurable).limit(3)

    # Spotlight representatives (featured cards on homepage)
    @spotlight_items = FeaturedItem.spotlights.includes(:featurable).limit(4)

    # Recent votes — most recent bill activity with vote data
    @recent_bills = Bill.with_votes.recent.limit(5)

    # Featured action scripts for "Take Action" section
    @action_scripts = ActionScript.active.featured.ordered.includes(:representative, :bill).limit(4)
  end

  def about
    set_meta_tags(
      title: "About",
      description: "Save Utah is a nonpartisan civic engagement platform tracking Utah elected officials and their voting records. Open data, plain language summaries, and action scripts."
    )
  end
end
