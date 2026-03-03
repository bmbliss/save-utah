module CensusGeocoder
  # Takes an address, calls the US Census Geocoder API,
  # parses the geography response to extract district numbers,
  # and queries the database for matching representatives.
  #
  # Census API returns district data in keys like:
  #   "119th Congressional Districts" → { "CD119" => "01" }
  #   "2024 State Legislative Districts - Upper" → { "SLDU" => "009" }
  #   "2024 State Legislative Districts - Lower" → { "SLDL" => "022" }
  class DistrictLookup
    class OutsideUtahError < StandardError; end
    class InvalidAddressError < StandardError; end

    # Returns an array of Representative records matching the given address.
    # Results are cached for 24 hours by normalized address.
    def call(address)
      address = address.to_s.strip
      raise InvalidAddressError, "Please enter an address." if address.blank?

      cache_key = "district_lookup/#{address.downcase.gsub(/\s+/, '_')}"

      districts = Rails.cache.fetch(cache_key, expires_in: 24.hours) do
        fetch_districts(address)
      end

      find_representatives(districts)
    end

    private

    # Calls the Census Geocoder and extracts district numbers from the response.
    # Example return: { cd: "1", sldu: "9", sldl: "22" }
    def fetch_districts(address)
      response = client.geocode(address)
      matches = response.dig("result", "addressMatches") || []

      if matches.empty?
        raise InvalidAddressError, "We couldn't find that address. Please enter a valid Utah street address."
      end

      geographies = matches.first["geographies"] || {}

      # Verify the address is in Utah (state FIPS code 49)
      state_fips = extract_state_fips(geographies)
      if state_fips && state_fips != "49"
        raise OutsideUtahError, "That address doesn't appear to be in Utah."
      end

      districts = {}

      # Congressional district — key name includes congress session number (e.g. "119th Congressional Districts")
      cd_data = geographies.find { |key, _| key.include?("Congressional Districts") }&.last&.first
      if cd_data
        cd_number = cd_data["CD119"] || cd_data.values_at(*cd_data.keys.grep(/^CD\d+/)).first
        districts[:cd] = cd_number.to_s.gsub(/\A0+/, "") if cd_number.present?
      end

      # State Senate (upper chamber)
      sldu_data = geographies.find { |key, _| key.include?("State Legislative Districts - Upper") }&.last&.first
      if sldu_data && sldu_data["SLDU"].present?
        districts[:sldu] = sldu_data["SLDU"].to_s.gsub(/\A0+/, "")
      end

      # State House (lower chamber)
      sldl_data = geographies.find { |key, _| key.include?("State Legislative Districts - Lower") }&.last&.first
      if sldl_data && sldl_data["SLDL"].present?
        districts[:sldl] = sldl_data["SLDL"].to_s.gsub(/\A0+/, "")
      end

      districts
    rescue ApiClient::ApiError => e
      raise InvalidAddressError, "We couldn't look up that address right now. Please try again later."
    end

    # Extracts the state FIPS code from any geography layer in the response.
    # Utah's FIPS code is "49".
    def extract_state_fips(geographies)
      geographies.each_value do |layers|
        next unless layers.is_a?(Array) && layers.first.is_a?(Hash)
        fips = layers.first["STATE"]
        return fips if fips.present?
      end
      nil
    end

    # Queries the representatives table for matching active Utah reps.
    # Always includes statewide officials (US Senators + executives).
    def find_representatives(districts)
      reps = Representative.active.where(state: "UT")

      # US Senators — statewide, always included
      senators = reps.where(position_type: :us_senator)

      # US House Rep — matched by congressional district
      house_rep = districts[:cd] ? reps.where(position_type: :us_representative, district: districts[:cd]) : Representative.none

      # State Senator — matched by state senate district
      state_senator = districts[:sldu] ? reps.where(position_type: :state_senator, district: districts[:sldu]) : Representative.none

      # State House Rep — matched by state house district
      state_rep = districts[:sldl] ? reps.where(position_type: :state_representative, district: districts[:sldl]) : Representative.none

      # Statewide executives (Governor, Lt. Gov, AG, etc.)
      executives = reps.executives

      # Combine and return, preserving a logical order
      (senators.to_a + house_rep.to_a + state_senator.to_a + state_rep.to_a + executives.to_a).uniq
    end

    def client
      @client ||= CensusGeocoder::Client.new
    end
  end
end
