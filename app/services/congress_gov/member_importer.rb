module CongressGov
  # Imports Utah's federal delegation from the Congress.gov API.
  # Maps Congress.gov member data to our Representative model.
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

      members.each do |member_data|
        import_member(member_data)
      end

      puts "  Done. #{members.size} members processed."
    end

    private

    def import_member(data)
      bioguide_id = data["bioguideId"]
      return if bioguide_id.blank?

      rep = Representative.find_or_initialize_by(bioguide_id: bioguide_id)

      # Determine position type from terms data
      terms = data["terms"]&.dig("item") || []
      current_term = terms.max_by { |t| t["startYear"].to_i }
      chamber = current_term&.dig("chamber")

      position_type = case chamber
      when "Senate" then :us_senator
      when "House of Representatives" then :us_representative
      else :us_representative
      end

      # Extract district from current term
      district = current_term&.dig("district")

      # Build title
      title = if position_type == :us_senator
                "U.S. Senator"
              else
                district ? "U.S. Representative, District #{district}" : "U.S. Representative"
              end

      rep.assign_attributes(
        first_name: data["firstName"],
        last_name: data["lastName"],
        full_name: data["directOrderName"] || "#{data['firstName']} #{data['lastName']}",
        title: title,
        position_type: position_type,
        level: :federal,
        chamber: chamber == "Senate" ? "Senate" : "House",
        party: normalize_party(data["partyName"]),
        district: district&.to_s,
        photo_url: data.dig("depiction", "imageUrl"),
        website_url: data["officialWebsiteUrl"],
        active: data["currentMember"] != false
      )

      if rep.save
        puts "  #{rep.new_record? ? 'Created' : 'Updated'}: #{rep.display_name}"
      else
        puts "  FAILED: #{rep.full_name} — #{rep.errors.full_messages.join(', ')}"
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
