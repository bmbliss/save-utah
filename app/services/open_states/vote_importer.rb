module OpenStates
  # Imports state-level vote data from the OpenStates API.
  # This is the PRIMARY source for state votes since the Utah Legislature API
  # has no dedicated vote endpoints.
  #
  # NOTE: OpenStates vote data lags — the current session often has 0 votes.
  # The importer targets recent completed sessions (2024, 2023, etc.) by default.
  #
  # Fetches bills with `include: "votes"` — each bill response contains a
  # `votes[]` array with individual vote records including:
  #   - option: "yes", "no", "absent", "abstain", etc.
  #   - voter_name: abbreviated name like "Snider, C."
  #   - voter.id: OCD person ID (matches Representative.openstates_id)
  class VoteImporter
    # Sessions known to have vote data in OpenStates.
    # The current/ongoing session usually has none until it closes.
    DEFAULT_SESSIONS = %w[2026 2025].freeze

    def initialize
      @client = Client.new
      # Cache state reps by openstates_id for quick lookup
      @state_reps_by_id = Representative.where(level: :state)
                                        .where.not(openstates_id: nil)
                                        .index_by(&:openstates_id)
      # Fallback: cache by last name for abbreviated name matching
      # Groups by last_name since there can be collisions (e.g., two Petersons)
      @state_reps_by_last = Representative.where(level: :state)
                                          .group_by { |r| r.last_name&.downcase }
    end

    # Import votes for given sessions. Defaults to recent completed sessions.
    # Pass session: "2024" to target a specific session.
    def import(sessions: nil, pages_per_session: 10)
      target_sessions = sessions || DEFAULT_SESSIONS
      target_sessions = Array(target_sessions)

      puts "Importing state votes from OpenStates..."
      puts "  Sessions: #{target_sessions.join(', ')}"

      grand_total_votes = 0
      grand_total_bills = 0

      target_sessions.each do |session|
        puts "  --- Session #{session} ---"
        session_votes, session_bills = import_session(session, pages_per_session)
        grand_total_votes += session_votes
        grand_total_bills += session_bills
      end

      puts "  Done. #{grand_total_votes} votes imported/updated across #{grand_total_bills} bills."
    end

    private

    # Imports votes for a single session. Returns [total_votes, total_bills].
    def import_session(session, pages)
      total_votes = 0
      total_bills = 0

      (1..pages).each do |page|
        # Pause between pages to respect OpenStates rate limits
        sleep(1) if page > 1
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

      [total_votes, total_bills]
    end

    # Processes all vote events for a single bill.
    # Returns the number of individual votes recorded.
    def process_bill_votes(bill_data)
      openstates_bill_id = bill_data["id"]
      identifier = bill_data["identifier"]
      return 0 if openstates_bill_id.blank?

      # Find the matching Bill record
      bill = find_bill(openstates_bill_id, identifier)
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

    # Finds a Bill by openstates_bill_id, then by normalized bill_number.
    # OpenStates uses "HB 1", our DB uses "HB0001" (from Utah Legislature API).
    def find_bill(openstates_bill_id, identifier)
      bill = Bill.find_by(openstates_bill_id: openstates_bill_id)
      return bill if bill

      # Try exact match first
      bill = Bill.find_by(bill_number: identifier, level: :state)
      return bill if bill

      # Normalize: "HB 1" → "HB0001", "SB 75" → "SB0075"
      normalized = normalize_bill_number(identifier)
      if normalized != identifier
        bill = Bill.find_by(bill_number: normalized, level: :state)
        return bill if bill
      end

      nil
    end

    # Converts OpenStates bill format to Utah Legislature format.
    # "HB 1" → "HB0001", "SB 75" → "SB0075", "HJR 3" → "HJR003"
    def normalize_bill_number(identifier)
      return identifier if identifier.blank?

      match = identifier.match(/\A([A-Z]+)\s*(\d+)\z/)
      return identifier unless match

      prefix = match[1]
      number = match[2]
      "#{prefix}#{number.rjust(4, '0')}"
    end

    # Records a single legislator's vote on a bill.
    # Matches the voter to a Representative via openstates_id or name fallback.
    def record_vote(individual_vote, bill, vote_date)
      # Try to find the representative by OCD person ID first
      voter_id = individual_vote.dig("voter", "id") || individual_vote["voter_id"]
      voter_name = individual_vote["voter_name"] || individual_vote.dig("voter", "name")

      rep = find_representative(voter_id, voter_name)
      return false unless rep

      # Backfill openstates_id if we matched by name and voter has an OCD ID
      if voter_id.present? && rep.openstates_id.blank?
        rep.update_columns(openstates_id: voter_id)
        @state_reps_by_id[voter_id] = rep
      end

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

    # Finds a Representative by openstates_id (preferred) or abbreviated name (fallback).
    # OpenStates vote names use "Last, First Initial." format like "Snider, C."
    def find_representative(voter_id, voter_name)
      # Primary: match by OpenStates person ID
      if voter_id.present?
        rep = @state_reps_by_id[voter_id]
        return rep if rep
      end

      return nil if voter_name.blank?

      # Parse abbreviated name: "Snider, C." → last_name="snider", initial="c"
      last_name, initial = parse_voter_name(voter_name)
      return nil if last_name.blank?

      candidates = @state_reps_by_last[last_name] || []

      # If only one rep with that last name, use them
      return candidates.first if candidates.length == 1

      # If multiple, narrow by first initial
      if initial.present? && candidates.length > 1
        match = candidates.find { |r| r.first_name&.downcase&.start_with?(initial) }
        return match if match
      end

      nil
    end

    # Parses OpenStates abbreviated voter name.
    # "Snider, C." → ["snider", "c"]
    # "Peterson, T." → ["peterson", "t"]
    # "Karen Peterson" → ["peterson", "k"]  (fallback for full names)
    def parse_voter_name(name)
      if name.include?(",")
        # "Last, F." format
        parts = name.split(",", 2).map(&:strip)
        last = parts[0]&.downcase
        initial = parts[1]&.gsub(".", "")&.strip&.downcase&.chars&.first
        [last, initial]
      else
        # "First Last" fallback
        parts = name.strip.split
        return [nil, nil] if parts.empty?
        last = parts.last&.downcase
        initial = parts.first&.downcase&.chars&.first
        [last, initial]
      end
    end

    # Normalizes OpenStates vote options to our position enum.
    # OpenStates uses: "yes", "no", "absent", "abstain", "not voting", "excused", "other"
    def normalize_position(option)
      case option&.downcase&.strip
      when "yes", "yea", "aye" then :yes
      when "no", "nay" then :no
      when "absent", "excused", "not voting", "other" then :not_voting
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
