module CongressGov
  # Imports federal vote data from the Congress.gov API.
  # Links roll call votes back to bills and Utah representatives.
  class VoteImporter
    def initialize
      @client = Client.new
      # Cache Utah reps by bioguide_id for quick lookup during vote processing
      @utah_reps = Representative.where(level: :federal).index_by(&:bioguide_id)
    end

    def import(congress: 119, session: 1, limit: 50)
      puts "Importing House votes from Congress.gov (Congress #{congress}, Session #{session})..."
      import_house_votes(congress, session, limit)
    end

    private

    def import_house_votes(congress, session, limit)
      votes_data = @client.house_votes(congress: congress, session: session, limit: limit)

      if votes_data.empty?
        puts "  No House votes returned."
        return
      end

      imported = 0
      votes_data.each do |vote_data|
        roll_number = vote_data["rollNumber"] || vote_data["number"]
        next unless roll_number

        # Fetch the detailed vote record with individual member votes
        begin
          detail = @client.house_vote(congress, session, roll_number)
          next unless detail

          # Try to link this vote to a bill
          bill = find_bill_for_vote(detail)
          next unless bill

          # Process individual member votes for Utah reps
          member_votes = detail.dig("members", "member") || detail.dig("members") || []
          member_votes.each do |mv|
            process_member_vote(mv, bill, detail)
          end

          imported += 1
        rescue ApiClient::ApiError => e
          puts "  Error fetching vote #{roll_number}: #{e.message}"
        end
      end

      puts "  Done. #{imported} roll calls processed."
    end

    # Attempts to find the bill associated with a roll call vote
    def find_bill_for_vote(vote_detail)
      legislation_number = vote_detail.dig("bill", "number") || vote_detail.dig("legislationNumber")
      legislation_type = vote_detail.dig("bill", "type") || vote_detail.dig("legislationType")
      congress = vote_detail.dig("bill", "congress") || vote_detail.dig("congress")

      return nil if legislation_number.blank? || legislation_type.blank?

      congress_bill_id = "#{congress}-#{legislation_type.downcase}-#{legislation_number}"
      Bill.find_by(congress_bill_id: congress_bill_id)
    end

    # Records a single member's vote if they're a Utah representative
    def process_member_vote(member_vote, bill, vote_detail)
      bioguide_id = member_vote["bioguideId"] || member_vote.dig("member", "bioguideId")
      return unless bioguide_id

      rep = @utah_reps[bioguide_id]
      return unless rep # Skip non-Utah members

      position = normalize_position(member_vote["voteType"] || member_vote["vote"])
      return unless position

      vote_date = parse_date(vote_detail["date"] || vote_detail["actionDate"])

      vote = Vote.find_or_initialize_by(representative: rep, bill: bill)
      vote.assign_attributes(
        position: position,
        voted_on: vote_date,
        data_source: "congress_gov"
      )

      if vote.save
        puts "    #{rep.last_name} voted #{position} on #{bill.bill_number}"
      end
    end

    def normalize_position(vote_type)
      case vote_type&.downcase
      when "yea", "aye", "yes" then :yes
      when "nay", "no" then :no
      when "present" then :present
      when "not voting" then :not_voting
      else nil
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
