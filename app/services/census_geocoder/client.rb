module CensusGeocoder
  # HTTP client for the US Census Geocoder API.
  # Free, no API key required.
  # Docs: https://geocoding.geo.census.gov/geocoder/Geocoding_Services_API.html
  class Client < ApiClient
    def base_url
      "https://geocoding.geo.census.gov/geocoder"
    end

    # Geocodes an address and returns geography data including
    # congressional districts and state legislative districts.
    # Returns the full parsed JSON response.
    def geocode(address)
      get("geographies/onelineaddress", {
        address: address,
        benchmark: "Public_AR_Current",
        vintage: "Current_Current",
        format: "json"
      })
    end

    private

    # No auth needed — Census Geocoder is free and open
    def configure_connection(conn)
      conn.headers["Accept"] = "application/json"
      # Census API can be slow; give it a generous timeout
      conn.options.timeout = 15
      conn.options.open_timeout = 10
    end
  end
end
