module UtahLegislature
  # Imports state floor votes from the Utah Legislature API.
  # Vote data is embedded in bill detail JSON — we fetch each bill's votes separately.
  class VoteImporter
    def initialize
      @client = Client.new
      # Cache state reps by utah_leg_id for quick lookup
      @state_reps = Representative.where(level: :state).index_by(&:utah_leg_id)
    end

    def import(session: "2025GS")
      puts "Importing state floor votes from Utah Legislature API (session: #{session})..."

      # Get all state bills that we've already imported
      bills = Bill.where(data_source: "utah_legislature", session_name: session_name_for(session))

      if bills.empty?
        puts "  No imported state bills found. Run import:state_bills first."
        return
      end

      imported = 0
      bills.find_each do |bill|
        bill_number = bill.bill_number
        begin
          votes_data = @client.bill_votes(session, bill_number)
          next if votes_data.empty?

          votes_data.each do |floor_vote|
            process_floor_vote(floor_vote, bill)
          end
          imported += 1
        rescue ApiClient::ApiError => e
          puts "  Error fetching votes for #{bill_number}: #{e.message}"
        end
      end

      puts "  Done. Processed votes for #{imported} bills."
    end

    private

    def process_floor_vote(floor_vote, bill)
      vote_date = parse_date(floor_vote["date"] || floor_vote["voteDate"])
      individual_votes = floor_vote["votes"] || floor_vote["individualVotes"] || []

      individual_votes.each do |iv|
        legislator_id = (iv["legislatorId"] || iv["id"])&.to_s
        next if legislator_id.blank?

        rep = @state_reps[legislator_id]
        next unless rep

        position = normalize_position(iv["vote"] || iv["result"])
        next unless position

        vote = Vote.find_or_initialize_by(representative: rep, bill: bill)
        vote.assign_attributes(
          position: position,
          voted_on: vote_date,
          data_source: "utah_legislature"
        )

        if vote.save
          puts "    #{rep.last_name} voted #{position} on #{bill.bill_number}"
        end
      end
    end

    def normalize_position(vote_value)
      case vote_value&.downcase&.strip
      when "yea", "yes", "y", "aye" then :yes
      when "nay", "no", "n" then :no
      when "absent", "abs" then :not_voting
      when "abstain" then :abstain
      else nil
      end
    end

    def session_name_for(session)
      case session
      when /GS$/ then "#{session.match(/\d{4}/)[0]} General Session"
      when /S\d+$/ then "#{session.match(/\d{4}/)[0]} Special Session"
      else session
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
