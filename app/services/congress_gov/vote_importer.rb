module CongressGov
  # Imports federal vote data from the Congress.gov API.
  # Links roll call votes back to bills and Utah representatives.
  #
  # Key API behaviors:
  # - house_votes list returns rollCallNumber, legislationNumber, legislationType
  # - Member votes are on a SEPARATE endpoint (/house-vote/.../members)
  # - Vote position field is "voteCast" (not "voteType" or "vote")
  class VoteImporter
    def initialize
      @client = Client.new
      # Cache Utah reps by bioguide_id for quick lookup during vote processing
      @utah_reps = Representative.where(level: :federal).index_by(&:bioguide_id)
    end

    def import(congress: 119, session: 1, page_size: 250)
      puts "Importing House votes from Congress.gov (Congress #{congress}, Session #{session})..."

      if @utah_reps.empty?
        puts "  No federal representatives found. Run import:federal_members first."
        return
      end

      import_house_votes(congress, session, page_size)
    end

    private

    def import_house_votes(congress, session, page_size)
      imported = 0
      skipped_no_bill = 0
      offset = 0

      loop do
        votes_data = @client.house_votes(congress: congress, session: session, limit: page_size, offset: offset)

        if votes_data.empty?
          puts "  No more roll calls found." if offset == 0
          break
        end

        puts "  Fetched #{votes_data.size} roll calls (offset #{offset})..."

        votes_data.each do |vote_data|
          roll_number = vote_data["rollCallNumber"] || vote_data["rollNumber"]
          next unless roll_number

          # Try to find or create the bill from the list data
          bill = find_or_create_bill(vote_data, congress)
          unless bill
            skipped_no_bill += 1
            next
          end

          begin
            # Fetch individual member votes from the SEPARATE members endpoint
            member_votes = @client.house_vote_members(congress, session, roll_number)

            utah_votes = 0
            member_votes.each do |mv|
              if process_member_vote(mv, bill, vote_data)
                utah_votes += 1
              end
            end

            imported += 1 if utah_votes > 0
          rescue ApiClient::ApiError => e
            puts "  Error fetching members for roll call #{roll_number}: #{e.message}"
          end
        end

        # Next page, or stop if we got fewer results than requested
        break if votes_data.size < page_size
        offset += page_size
      end

      puts "  Done. #{imported} roll calls with Utah votes processed."
      puts "  Skipped #{skipped_no_bill} roll calls (no bill linkage)." if skipped_no_bill > 0
    end

    # Finds an existing bill or creates a stub from the vote list data.
    # The vote list includes legislationNumber, legislationType, and legislationUrl.
    def find_or_create_bill(vote_data, congress)
      legislation_number = vote_data["legislationNumber"]
      legislation_type = vote_data["legislationType"]
      return nil if legislation_number.blank? || legislation_type.blank?

      congress_bill_id = "#{congress}-#{legislation_type.downcase}-#{legislation_number}"

      bill = Bill.find_by(congress_bill_id: congress_bill_id)
      return bill if bill

      # Create a stub bill so we can link the vote
      bill_number = "#{legislation_type.upcase} #{legislation_number}"
      chamber = case legislation_type.downcase
      when "s", "sres", "sjres", "sconres" then "Senate"
      when "hr", "hres", "hjres", "hconres" then "House"
      else nil
      end

      bill = Bill.new(
        congress_bill_id: congress_bill_id,
        title: "#{bill_number} (details pending import)",
        bill_number: bill_number,
        level: :federal,
        chamber: chamber,
        session_year: Date.today.year,
        session_name: "#{congress}th Congress",
        data_source: "congress_gov"
      )

      if bill.save
        puts "  Created stub bill: #{bill_number}"
        bill
      else
        nil
      end
    end

    # Records a single member's vote if they're a Utah representative.
    # Returns true if a vote was recorded.
    def process_member_vote(member_vote, bill, vote_data)
      bioguide_id = member_vote["bioguideId"] || member_vote.dig("member", "bioguideId")
      return false unless bioguide_id

      rep = @utah_reps[bioguide_id]
      return false unless rep # Skip non-Utah members

      # Try voteCast first, fall back to other field names
      position = normalize_position(member_vote["voteCast"] || member_vote["voteType"] || member_vote["vote"])
      return false unless position

      vote_date = parse_date(vote_data["startDate"] || vote_data["date"])

      vote = Vote.find_or_initialize_by(representative: rep, bill: bill)
      vote.assign_attributes(
        position: position,
        voted_on: vote_date,
        data_source: "congress_gov"
      )

      if vote.save
        puts "    #{rep.last_name} voted #{position} on #{bill.bill_number}"
        true
      else
        false
      end
    end

    # Normalizes Congress.gov vote positions to our enum values.
    # Congress.gov uses: "Aye", "Nay", "Present", "Not Voting"
    def normalize_position(vote_type)
      case vote_type&.strip
      when "Aye", "Yea" then :yes
      when "Nay", "No" then :no
      when "Present" then :present
      when "Not Voting" then :not_voting
      else
        case vote_type&.downcase&.strip
        when "aye", "yea", "yes" then :yes
        when "nay", "no" then :no
        when "present" then :present
        when "not voting" then :not_voting
        else nil
        end
      end
    end

    def parse_date(date_string)
      return nil if date_string.blank?
      Date.parse(date_string)
    rescue Date::Error
      nil
    end
  end
end
