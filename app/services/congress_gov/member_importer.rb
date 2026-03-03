module CongressGov
  # Imports Utah's federal delegation from the Congress.gov API.
  # Maps Congress.gov member data to our Representative model.
  #
  # The list endpoint (/member?stateCode=UT) returns a sparse response with
  # only name (inverted), bioguideId, partyName, district, depiction, and terms.
  # A detail call (/member/{bioguideId}) is needed for firstName, lastName,
  # directOrderName, officialWebsiteUrl, phone, etc.
  # Utah only has ~6-8 members so the extra API calls are trivial.
  class MemberImporter
    def initialize
      @client = Client.new
    end

    def import
      puts "Importing federal members from Congress.gov..."
      members = @client.utah_members

      if members.empty?
        puts "  No members returned. Check your CONGRESS_GOV_API_KEY."
        return
      end

      imported = 0
      members.each do |list_data|
        bioguide_id = list_data["bioguideId"]
        next if bioguide_id.blank?

        # Fetch full detail for each member (list endpoint is sparse)
        begin
          detail = @client.member(bioguide_id)
          next unless detail

          if import_member(list_data, detail)
            imported += 1
          end
        rescue ApiClient::ApiError => e
          puts "  Error fetching detail for #{bioguide_id}: #{e.message}"
        end
      end

      puts "  Done. #{imported} members imported/updated."
    end

    private

    # Merges sparse list data with full detail data to build the representative.
    # Detail fields take priority when available.
    def import_member(list_data, detail)
      bioguide_id = detail["bioguideId"] || list_data["bioguideId"]
      return false if bioguide_id.blank?

      rep = Representative.find_or_initialize_by(bioguide_id: bioguide_id)

      # Determine position type from terms data (available on both list and detail).
      # Terms can be an Array directly or a Hash with an "item" key depending on endpoint.
      raw_terms = detail["terms"] || list_data["terms"]
      terms = case raw_terms
      when Array then raw_terms
      when Hash then raw_terms["item"] || []
      else []
      end
      current_term = terms.max_by { |t| t["startYear"].to_i }
      chamber = current_term&.dig("chamber")

      position_type = case chamber
      when "Senate" then :us_senator
      when "House of Representatives" then :us_representative
      else :us_representative
      end

      # State + district from current term
      state_code = current_term&.dig("stateCode")
      district = current_term&.dig("district")

      # Build title
      title = if position_type == :us_senator
                "U.S. Senator"
              else
                district ? "U.S. Representative, District #{district}" : "U.S. Representative"
              end

      # Name fields from detail (not available on list endpoint)
      first_name = detail["firstName"]
      last_name = detail["lastName"]
      full_name = detail["directOrderName"] || "#{first_name} #{last_name}"

      # If detail didn't have names, try parsing the inverted "name" from list
      if first_name.blank? && list_data["name"].present?
        parts = list_data["name"].split(",", 2).map(&:strip)
        last_name = parts[0]
        first_name = parts[1]
        full_name = "#{first_name} #{last_name}"
      end

      # Photo from depiction (available on both list and detail)
      photo_url = detail.dig("depiction", "imageUrl") || list_data.dig("depiction", "imageUrl")

      # Website and phone from detail only
      website_url = detail["officialWebsiteUrl"]
      phone = detail.dig("addressInformation", "officePhone")

      rep.assign_attributes(
        first_name: first_name,
        last_name: last_name,
        full_name: full_name,
        title: title,
        position_type: position_type,
        level: :federal,
        state: state_code || "UT",
        chamber: chamber == "Senate" ? "Senate" : "House",
        party: normalize_party(detail["partyName"] || list_data["partyName"]),
        district: district&.to_s,
        photo_url: photo_url,
        website_url: website_url,
        phone: phone,
        active: detail["currentMember"] != false
      )

      if rep.save
        puts "  #{rep.display_name}"
        true
      else
        puts "  FAILED: #{full_name} — #{rep.errors.full_messages.join(', ')}"
        false
      end
    end

    def normalize_party(party_name)
      case party_name&.downcase
      when "republican" then "Republican"
      when "democratic", "democrat" then "Democrat"
      when "independent" then "Independent"
      else party_name
      end
    end
  end
end
