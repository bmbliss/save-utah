module OpenStates
  # HTTP client for the OpenStates API v3 (v3.openstates.org)
  # Docs: https://docs.openstates.org/api-v3/
  # Used as a supplementary/fallback data source, and as the PRIMARY
  # source for state-level vote data (Utah Legislature API has no vote endpoints).
  class Client < ApiClient
    VALID_CHAMBERS = %w[upper lower].freeze

    def base_url
      "https://v3.openstates.org"
    end

    # Fetches Utah legislators
    # chamber must be "upper" or "lower" (OpenStates org_classification values)
    def utah_people(chamber: nil)
      params = { jurisdiction: "Utah", include: "other_identifiers" }

      if chamber.present?
        normalized = chamber.to_s.downcase
        if VALID_CHAMBERS.include?(normalized)
          params[:org_classification] = normalized
        else
          log("WARNING: Invalid chamber '#{chamber}'. Must be 'upper' or 'lower'. Fetching all.")
        end
      end

      data = get("/people", params)
      data.dig("results") || []
    end

    # Fetches a single person by OpenStates ID
    def person(openstates_id)
      get("/people/#{openstates_id}")
    end

    # Fetches Utah bills, optionally with embedded vote data
    # Pass include_votes: true to get individual legislator vote records
    # OpenStates v3 caps per_page at 20
    def utah_bills(session: nil, page: 1, per_page: 20, include_votes: false)
      params = { jurisdiction: "Utah", per_page: [per_page, 20].min, page: page }
      params[:session] = session if session.present?
      params[:include] = "votes" if include_votes

      data = get("/bills", params)
      data.dig("results") || []
    end

    # Fetches a single bill by OpenStates ID
    def bill(openstates_id, include_votes: false)
      params = {}
      params[:include] = "votes" if include_votes
      data = get("/bills/#{openstates_id}", params)
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
