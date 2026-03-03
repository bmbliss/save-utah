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

  desc "Import federal Senate votes from senate.gov XML"
  task federal_senate_votes: :environment do
    SenateGov::VoteImporter.new.import
  end

  desc "Import state floor votes from OpenStates API (primary source for state votes)"
  task state_votes: :environment do
    OpenStates::VoteImporter.new.import
  end

  desc "Import state floor votes from OpenStates API"
  task openstates_votes: :environment do
    OpenStates::VoteImporter.new.import
  end

  desc "Import state floor votes from Utah Legislature API (if bill detail includes votes)"
  task utah_legislature_votes: :environment do
    UtahLegislature::VoteImporter.new.import
  end

  desc "Backfill federal bill stubs created by vote importer with full details"
  task backfill_federal_stubs: :environment do
    client = CongressGov::Client.new
    stubs = Bill.where(level: :federal).where("title LIKE ?", "%(details pending import)%")

    if stubs.empty?
      puts "No federal bill stubs to backfill."
      next
    end

    puts "Backfilling #{stubs.count} federal bill stubs..."
    updated = 0

    stubs.find_each do |bill|
      # Parse congress_bill_id: "119-hr-1234" → congress=119, type=hr, number=1234
      parts = bill.congress_bill_id&.split("-")
      unless parts&.length == 3
        puts "  SKIP: Cannot parse congress_bill_id '#{bill.congress_bill_id}' for #{bill.bill_number}"
        next
      end

      congress, bill_type, number = parts
      sleep(0.5) # Courtesy delay between API calls

      begin
        data = client.bill(congress, bill_type, number)
        unless data
          puts "  SKIP: No data returned for #{bill.bill_number}"
          next
        end

        bill.assign_attributes(
          title: data["title"] || bill.title,
          summary: data.dig("summaries", "billSummaries", 0, "text") || data["latestAction"]&.dig("text") || bill.summary,
          status: data.dig("latestAction", "text")&.truncate(100) || bill.status,
          introduced_on: data["introducedDate"] ? Date.parse(data["introducedDate"]) : bill.introduced_on,
          last_action_on: data.dig("latestAction", "actionDate") ? Date.parse(data.dig("latestAction", "actionDate")) : bill.last_action_on
        )

        if bill.save
          puts "  UPDATED: #{bill.bill_number} — #{bill.title.truncate(60)}"
          updated += 1
        else
          puts "  FAILED: #{bill.bill_number} — #{bill.errors.full_messages.join(', ')}"
        end
      rescue ApiClient::ApiError => e
        puts "  ERROR: #{bill.bill_number} — #{e.message}"
      rescue Date::Error => e
        puts "  ERROR: #{bill.bill_number} — bad date: #{e.message}"
      end
    end

    puts "Backfill complete. #{updated}/#{stubs.count} stubs updated."
  end

  desc "Import all members (federal + state + OpenStates IDs)"
  task all_members: :environment do
    Rake::Task["import:federal_members"].invoke
    Rake::Task["import:state_legislators"].invoke
    Rake::Task["import:openstates_people"].invoke
  end

  desc "Import all bills (federal + state)"
  task all_bills: :environment do
    Rake::Task["import:federal_bills"].invoke
    Rake::Task["import:state_bills"].invoke
  end

  desc "Import all votes (federal House + Senate + state)"
  task all_votes: :environment do
    Rake::Task["import:federal_votes"].invoke
    Rake::Task["import:federal_senate_votes"].invoke
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
    Rake::Task["import:backfill_federal_stubs"].invoke

    puts
    puts "=" * 60
    puts "Import complete!"
    puts "  Representatives: #{Representative.count}"
    puts "  Bills: #{Bill.count}"
    puts "  Votes: #{Vote.count}"
    puts "=" * 60
  end
end
