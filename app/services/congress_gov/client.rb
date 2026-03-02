module CongressGov
  # HTTP client for the Congress.gov API (api.congress.gov/v3)
  # Docs: https://api.congress.gov/
  # Rate limit: 5,000 requests/hour with API key
  class Client < ApiClient
    def base_url
      "https://api.congress.gov/v3"
    end

    # Fetches Utah members of Congress
    # Returns array of member hashes
    def utah_members
      results = []

      # Get current members from Utah
      data = get("/member", { stateCode: "UT", currentMember: true, limit: 20 })
      results.concat(data.dig("members") || [])

      results
    end

    # Fetches a single member by bioguide ID
    def member(bioguide_id)
      data = get("/member/#{bioguide_id}")
      data.dig("member")
    end

    # Fetches recent bills (optionally filtered by congress number)
    def bills(congress: 119, limit: 50, offset: 0)
      data = get("/bill/#{congress}", { limit: limit, offset: offset, sort: "updateDate+desc" })
      data.dig("bills") || []
    end

    # Fetches a specific bill
    def bill(congress, bill_type, bill_number)
      data = get("/bill/#{congress}/#{bill_type}/#{bill_number}")
      data.dig("bill")
    end

    # Fetches actions/votes for a specific bill
    def bill_actions(congress, bill_type, bill_number)
      data = get("/bill/#{congress}/#{bill_type}/#{bill_number}/actions")
      data.dig("actions") || []
    end

    # Fetches House roll call votes
    def house_votes(congress: 119, session: 1, limit: 50)
      data = get("/house-vote/#{congress}/#{session}", { limit: limit })
      data.dig("votes") || []
    end

    # Fetches a specific House roll call vote
    def house_vote(congress, session, roll_number)
      data = get("/house-vote/#{congress}/#{session}/#{roll_number}")
      data.dig("vote")
    end

    private

    def configure_connection(conn)
      api_key = ENV.fetch("CONGRESS_GOV_API_KEY", nil)
      if api_key.present?
        conn.params["api_key"] = api_key
      else
        log("WARNING: CONGRESS_GOV_API_KEY not set. Requests will be rate-limited.")
      end

      conn.headers["Accept"] = "application/json"
    end
  end
end
