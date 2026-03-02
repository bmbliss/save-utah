namespace :import do
  desc "Import Utah's federal delegation from Congress.gov API"
  task federal_members: :environment do
    CongressGov::MemberImporter.new.import
  end

  desc "Import state legislators from Utah Legislature API"
  task state_legislators: :environment do
    UtahLegislature::LegislatorImporter.new.import
  end

  desc "Import state legislators from OpenStates API (fallback)"
  task openstates_people: :environment do
    OpenStates::PeopleImporter.new.import
  end

  desc "Import federal bills from Congress.gov API"
  task federal_bills: :environment do
    CongressGov::BillImporter.new.import
  end

  desc "Import state bills from Utah Legislature API"
  task state_bills: :environment do
    UtahLegislature::BillImporter.new.import
  end

  desc "Import state bills from OpenStates API (fallback)"
  task openstates_bills: :environment do
    OpenStates::BillImporter.new.import
  end

  desc "Import federal House votes from Congress.gov API"
  task federal_votes: :environment do
    CongressGov::VoteImporter.new.import
  end

  desc "Import state floor votes from Utah Legislature API"
  task state_votes: :environment do
    UtahLegislature::VoteImporter.new.import
  end

  desc "Import all members (federal + state)"
  task all_members: :environment do
    Rake::Task["import:federal_members"].invoke
    Rake::Task["import:state_legislators"].invoke
  end

  desc "Import all bills (federal + state)"
  task all_bills: :environment do
    Rake::Task["import:federal_bills"].invoke
    Rake::Task["import:state_bills"].invoke
  end

  desc "Import all votes (federal + state)"
  task all_votes: :environment do
    Rake::Task["import:federal_votes"].invoke
    Rake::Task["import:state_votes"].invoke
  end

  desc "Run full import: all members, bills, and votes"
  task all: :environment do
    puts "=" * 60
    puts "SAVE UTAH — Full Data Import"
    puts "=" * 60
    puts

    Rake::Task["import:all_members"].invoke
    puts
    Rake::Task["import:all_bills"].invoke
    puts
    Rake::Task["import:all_votes"].invoke

    puts
    puts "=" * 60
    puts "Import complete!"
    puts "  Representatives: #{Representative.count}"
    puts "  Bills: #{Bill.count}"
    puts "  Votes: #{Vote.count}"
    puts "=" * 60
  end
end
