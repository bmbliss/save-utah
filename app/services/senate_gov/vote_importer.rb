module SenateGov
  # Imports US Senate vote data from senate.gov XML feeds.
  # This fills the gap where Congress.gov API only provides House votes.
  #
  # Matching strategy: Since Utah has exactly 2 US Senators, we match by
  # state="UT" + last_name from a cached hash. This avoids needing a
  # lis_member_id column in the database.
  class VoteImporter
    def initialize
      @client = Client.new
      # Cache Utah senators by downcased last name for quick lookup
      # Only 2 senators per state, so name collision is impossible
      @utah_senators = Representative.where(level: :federal, position_type: :us_senator)
                                     .index_by { |r| r.last_name.downcase }
    end

    def import(congress: 119, session: 1)
      puts "Importing Senate votes from senate.gov (Congress #{congress}, Session #{session})..."

      if @utah_senators.empty?
        puts "  No Utah senators found. Run import:federal_members first."
        return
      end

      puts "  Utah senators: #{@utah_senators.values.map(&:last_name).join(', ')}"

      vote_list = @client.vote_list(congress: congress, session: session)
      if vote_list.empty?
        puts "  No votes found for Congress #{congress}, Session #{session}."
        return
      end

      puts "  Found #{vote_list.size} roll call votes. Processing..."

      imported = 0
      vote_list.each_with_index do |vote_info, idx|
        sleep(0.5) if idx > 0 # Courtesy delay between requests

        vote_number = vote_info[:vote_number]
        next if vote_number.blank?

        utah_votes = process_vote(congress, session, vote_number, vote_info)
        imported += 1 if utah_votes > 0
      end

      puts "  Done. #{imported} roll calls with Utah senator votes processed."
    end

    private

    # Processes a single roll call vote. Returns number of Utah votes recorded.
    def process_vote(congress, session, vote_number, vote_info)
      detail = @client.vote_detail(congress: congress, session: session, number: vote_number)
      return 0 unless detail

      # Find or create the bill from the vote's document element
      bill = find_or_create_bill_from_vote(detail, congress)
      return 0 unless bill

      vote_date = parse_vote_date(detail)
      utah_votes = 0

      # Iterate over all member votes, filtering for Utah senators
      detail.elements.each("roll_call_vote/members/member") do |member_el|
        state = member_el.elements["state"]&.text&.strip
        next unless state == "UT"

        last_name = member_el.elements["last_name"]&.text&.strip&.downcase
        next if last_name.blank?

        rep = @utah_senators[last_name]
        unless rep
          puts "  WARNING: Utah senator not found in DB — last_name=#{last_name}"
          next
        end

        vote_cast = member_el.elements["vote_cast"]&.text&.strip
        position = normalize_position(vote_cast)
        unless position
          puts "  WARNING: Unknown Senate vote '#{vote_cast}' for #{rep.last_name} on #{bill.bill_number}"
          next
        end

        vote = Vote.find_or_initialize_by(representative: rep, bill: bill)
        vote.assign_attributes(
          position: position,
          voted_on: vote_date,
          data_source: "senate_gov"
        )

        if vote.save
          puts "    #{rep.last_name} voted #{position} on #{bill.bill_number}"
          utah_votes += 1
        end
      end

      utah_votes
    end

    # Finds or creates a bill from the vote detail XML's <document> element.
    # Senate votes reference bills like "H.R. 1234" or "S. 567" in the document_name.
    def find_or_create_bill_from_vote(detail, congress)
      doc_el = detail.elements["roll_call_vote/document"]
      return nil unless doc_el

      doc_name = doc_el.elements["document_name"]&.text&.strip
      doc_title = doc_el.elements["document_title"]&.text&.strip
      return nil if doc_name.blank?

      # Parse document_name: "H.R. 1234", "S. 567", "H.J.Res. 12", "S.Res. 45", etc.
      bill_type, number = parse_document_name(doc_name)
      return nil unless bill_type && number

      congress_bill_id = "#{congress}-#{bill_type}-#{number}"

      # Try to find existing bill
      bill = Bill.find_by(congress_bill_id: congress_bill_id)
      return bill if bill

      # Create a stub bill so we can link the vote
      bill_number = "#{bill_type.upcase} #{number}"
      chamber = case bill_type
      when "s", "sres", "sjres", "sconres" then "Senate"
      when "hr", "hres", "hjres", "hconres" then "House"
      else nil
      end

      bill = Bill.new(
        congress_bill_id: congress_bill_id,
        title: doc_title.present? ? doc_title.truncate(255) : "#{bill_number} (details pending import)",
        bill_number: bill_number,
        level: :federal,
        chamber: chamber,
        session_year: Date.today.year,
        session_name: "#{congress}th Congress",
        data_source: "senate_gov"
      )

      if bill.save
        puts "  Created stub bill: #{bill_number}"
        bill
      else
        puts "  FAILED to create bill: #{bill_number} — #{bill.errors.full_messages.join(', ')}"
        nil
      end
    end

    # Parses Senate document_name into [type, number] matching congress_bill_id format.
    # "H.R. 1234"    → ["hr", "1234"]
    # "S. 567"        → ["s", "567"]
    # "H.J.Res. 12"  → ["hjres", "12"]
    # "S.J.Res. 45"  → ["sjres", "45"]
    # "S.Res. 10"    → ["sres", "10"]
    # "H.Res. 10"    → ["hres", "10"]
    # "S.Con.Res. 5" → ["sconres", "5"]
    # "H.Con.Res. 5" → ["hconres", "5"]
    def parse_document_name(name)
      case name
      when /\AH\.?R\.?\s*(\d+)\z/i
        ["hr", $1]
      when /\AS\.?\s*(\d+)\z/i
        ["s", $1]
      when /\AH\.?J\.?Res\.?\s*(\d+)\z/i
        ["hjres", $1]
      when /\AS\.?J\.?Res\.?\s*(\d+)\z/i
        ["sjres", $1]
      when /\AH\.?Res\.?\s*(\d+)\z/i
        ["hres", $1]
      when /\AS\.?Res\.?\s*(\d+)\z/i
        ["sres", $1]
      when /\AH\.?Con\.?Res\.?\s*(\d+)\z/i
        ["hconres", $1]
      when /\AS\.?Con\.?Res\.?\s*(\d+)\z/i
        ["sconres", $1]
      else
        puts "  WARNING: Could not parse Senate document name: '#{name}'"
        [nil, nil]
      end
    end

    # Normalizes Senate vote positions to our enum values.
    # Senate uses: "Yea", "Nay", "Not Voting", "Present"
    def normalize_position(vote_cast)
      case vote_cast&.strip
      when "Yea" then :yes
      when "Nay" then :no
      when "Not Voting" then :not_voting
      when "Present" then :present
      else
        case vote_cast&.downcase&.strip
        when "yea", "yes", "aye" then :yes
        when "nay", "no" then :no
        when "not voting" then :not_voting
        when "present" then :present
        else nil
        end
      end
    end

    # Extracts vote date from the detail XML.
    def parse_vote_date(detail)
      date_str = detail.elements["roll_call_vote/vote_date"]&.text&.strip
      return nil if date_str.blank?

      # Format is typically "January 3, 2025, 02:15 PM" — parse just the date portion
      Date.parse(date_str)
    rescue Date::Error
      nil
    end
  end
end
