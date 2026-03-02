module UtahLegislature
  # HTTP client for the Utah Legislature API (glen.le.utah.gov)
  # Docs: https://glen.le.utah.gov/
  # Rate limits: 1 request/hour for bills, 1 request/day for legislators
  # Authentication: developer token appended to URL
  class Client < ApiClient
    def base_url
      "https://glen.le.utah.gov"
    end

    # Fetches all current legislators
    def legislators
      data = get("/legislators", { year: Date.today.year })
      data.is_a?(Array) ? data : (data.dig("legislators") || [])
    end

    # Fetches a specific legislator by ID
    def legislator(legislator_id)
      data = get("/legislators/#{legislator_id}")
      data.dig("legislator") || data
    end

    # Fetches bills for a given session
    def bills(session: "2025GS")
      data = get("/bills/#{session}")
      data.is_a?(Array) ? data : (data.dig("bills") || [])
    end

    # Fetches a specific bill with detail (including votes)
    def bill(session, bill_number)
      data = get("/bills/#{session}/#{bill_number}")
      data.dig("bill") || data
    end

    # Fetches floor votes for a bill (embedded in bill detail)
    def bill_votes(session, bill_number)
      bill_data = bill(session, bill_number)
      bill_data.dig("floorVotes") || bill_data.dig("votes") || []
    end

    private

    def configure_connection(conn)
      token = ENV.fetch("UTAH_LEGISLATURE_TOKEN", nil)
      if token.present?
        conn.params["token"] = token
      else
        log("WARNING: UTAH_LEGISLATURE_TOKEN not set. API requests may fail.")
      end

      conn.headers["Accept"] = "application/json"
    end
  end
end
