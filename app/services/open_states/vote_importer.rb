module OpenStates
  # Imports state-level vote data from the OpenStates API.
  # This is the PRIMARY source for state votes since the Utah Legislature API
  # has no dedicated vote endpoints.
  #
  # Fetches bills with `include: "votes"` — each bill response contains a
  # `votes[]` array with individual vote records including:
  #   - option: "yes", "no", "absent", "abstain", etc.
  #   - voter_name: display name of the legislator
  #   - voter.id: OCD person ID (matches Representative.openstates_id)
  class VoteImporter
    def initialize
      @client = Client.new
      # Cache state reps by openstates_id for quick lookup
      @state_reps_by_id = Representative.where(level: :state)
                                        .where.not(openstates_id: nil)
                                        .index_by(&:openstates_id)
      # Fallback: cache by full name for name-based matching
      @state_reps_by_name = Representative.where(level: :state)
                                          .index_by(&:full_name)
    end

    def import(session: nil, pages: 5)
      puts "Importing state votes from OpenStates..."

      total_votes = 0
      total_bills = 0

      (1..pages).each do |page|
        bills_data = @client.utah_bills(session: session, page: page, include_votes: true)
        break if bills_data.empty?

        bills_data.each do |bill_data|
          votes_for_bill = process_bill_votes(bill_data)
          if votes_for_bill > 0
            total_bills += 1
            total_votes += votes_for_bill
          end
        end
      end

      puts "  Done. #{total_votes} votes imported/updated across #{total_bills} bills."
    end

    private

    # Processes all vote events for a single bill.
    # Returns the number of individual votes recorded.
    def process_bill_votes(bill_data)
      openstates_bill_id = bill_data["id"]
      identifier = bill_data["identifier"]
      return 0 if openstates_bill_id.blank?

      # Find the matching Bill record — try openstates_bill_id first, then bill_number
      bill = Bill.find_by(openstates_bill_id: openstates_bill_id)
      bill ||= Bill.find_by(bill_number: identifier, level: :state)
      return 0 unless bill

      vote_events = bill_data["votes"] || []
      return 0 if vote_events.empty?

      votes_recorded = 0

      vote_events.each do |vote_event|
        vote_date = parse_date(vote_event["start_date"] || vote_event["startDate"])

        # Each vote event has individual counts in "counts" and individual
        # legislator votes in "votes"
        individual_votes = vote_event["votes"] || []

        individual_votes.each do |iv|
          if record_vote(iv, bill, vote_date)
            votes_recorded += 1
          end
        end
      end

      votes_recorded
    end

    # Records a single legislator's vote on a bill.
    # Matches the voter to a Representative via openstates_id or name fallback.
    def record_vote(individual_vote, bill, vote_date)
      # Try to find the representative by OCD person ID first
      voter_id = individual_vote.dig("voter", "id") || individual_vote["voter_id"]
      voter_name = individual_vote["voter_name"] || individual_vote.dig("voter", "name")

      rep = find_representative(voter_id, voter_name)
      return false unless rep

      # Map vote option to our position enum
      option = individual_vote["option"] || individual_vote["vote"]
      position = normalize_position(option)
      return false unless position

      vote = Vote.find_or_initialize_by(representative: rep, bill: bill)
      vote.assign_attributes(
        position: position,
        voted_on: vote_date,
        data_source: "openstates"
      )

      if vote.save
        puts "    #{rep.last_name} voted #{position} on #{bill.bill_number}"
        true
      else
        false
      end
    end

    # Finds a Representative by openstates_id (preferred) or name (fallback)
    def find_representative(voter_id, voter_name)
      # Primary: match by OpenStates person ID
      if voter_id.present?
        rep = @state_reps_by_id[voter_id]
        return rep if rep
      end

      # Fallback: match by full name
      if voter_name.present?
        rep = @state_reps_by_name[voter_name]
        return rep if rep

        # Try case-insensitive name match as last resort
        Representative.where(level: :state).find_by(
          "LOWER(full_name) = ?", voter_name.downcase
        )
      end
    end

    # Normalizes OpenStates vote options to our position enum.
    # OpenStates uses: "yes", "no", "absent", "abstain", "not voting", "excused"
    def normalize_position(option)
      case option&.downcase&.strip
      when "yes", "yea", "aye" then :yes
      when "no", "nay" then :no
      when "absent", "excused", "not voting" then :not_voting
      when "abstain" then :abstain
      when "present" then :present
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
