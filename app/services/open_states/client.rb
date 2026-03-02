module OpenStates
  # HTTP client for the OpenStates API v3 (v3.openstates.org)
  # Docs: https://docs.openstates.org/api-v3/
  # Used as a supplementary/fallback data source.
  class Client < ApiClient
    def base_url
      "https://v3.openstates.org"
    end

    # Fetches Utah legislators
    def utah_people(chamber: nil)
      params = { jurisdiction: "Utah", include: "other_identifiers" }
      params[:org_classification] = chamber.downcase if chamber.present?
      data = get("/people", params)
      data.dig("results") || []
    end

    # Fetches a single person by OpenStates ID
    def person(openstates_id)
      data = get("/people/#{openstates_id}")
      data
    end

    # Fetches Utah bills
    def utah_bills(session: nil, page: 1, per_page: 50)
      params = { jurisdiction: "Utah", per_page: per_page, page: page }
      params[:session] = session if session.present?
      data = get("/bills", params)
      data.dig("results") || []
    end

    # Fetches a single bill by OpenStates ID
    def bill(openstates_id)
      data = get("/bills/#{openstates_id}")
      data
    end

    private

    def configure_connection(conn)
      api_key = ENV.fetch("OPENSTATES_API_KEY", nil)
      if api_key.present?
        conn.headers["X-API-KEY"] = api_key
      else
        log("WARNING: OPENSTATES_API_KEY not set. Requests will fail.")
      end

      conn.headers["Accept"] = "application/json"
    end
  end
end
