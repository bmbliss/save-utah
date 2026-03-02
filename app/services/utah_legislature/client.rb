module UtahLegislature
  # HTTP client for the Utah Legislature API (glen.le.utah.gov)
  # Docs: https://le.utah.gov/data/developer.htm
  # Rate limits: 1 request/hour for bills, 1 request/day for legislators
  # Authentication: developer token appended to URL path (NOT query param)
  class Client < ApiClient
    def base_url
      "https://glen.le.utah.gov"
    end

    # Fetches all current legislators
    # GET /legislators/{token}
    def legislators
      data = get("/legislators/#{token}")
      data.is_a?(Array) ? data : (data.dig("legislators") || [])
    end

    # Fetches bills for a given session
    # GET /bills/{session}/billlist/{token}
    def bills(session: "2025GS")
      data = get("/bills/#{session}/billlist/#{token}")
      data.is_a?(Array) ? data : (data.dig("bills") || [])
    end

    # Fetches a specific bill with detail (including possibly embedded votes)
    # GET /bills/{session}/{billNumber}/{token}
    def bill(session, bill_number)
      data = get("/bills/#{session}/#{bill_number}/#{token}")
      data.dig("bill") || data
    end

    # Fetches floor votes for a bill (embedded in bill detail JSON)
    def bill_votes(session, bill_number)
      bill_data = bill(session, bill_number)
      bill_data.dig("floorVotes") || bill_data.dig("votes") || []
    end

    private

    # Returns the API token, raising if not configured
    def token
      @token ||= ENV.fetch("UTAH_LEGISLATURE_TOKEN") do
        log("WARNING: UTAH_LEGISLATURE_TOKEN not set. API requests will fail.")
        nil
      end
    end

    def configure_connection(conn)
      # Token goes in the URL path, not as a query param or header
      conn.headers["Accept"] = "application/json"
    end
  end
end
