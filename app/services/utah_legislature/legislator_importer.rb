module UtahLegislature
  # Imports state legislators from the Utah Legislature API.
  # Maps Utah Legislature data to our Representative model.
  #
  # Actual API field names (from /legislators/{token}):
  #   fullName      — "Peterson, Thomas W." (inverted)
  #   formatName    — "Thomas W. Peterson" (display order)
  #   id            — "PETERT" (short code)
  #   image         — full URL to headshot
  #   house         — "H" or "S"
  #   party         — "R", "D", etc.
  #   district      — "1", "2", etc.
  #   email         — legislative email
  #   cell          — cell phone
  #   workPhone     — work phone
  #   homePhone     — home phone
  #   address       — mailing address
  #   counties      — counties represented
  #   serviceStart  — "September 21, 2022"
  #   legislation   — URL to their bills page
  class LegislatorImporter
    def initialize
      @client = Client.new
    end

    def import
      puts "Importing state legislators from Utah Legislature API..."
      legislators = @client.legislators

      if legislators.empty?
        puts "  No legislators returned. Check your UTAH_LEGISLATURE_TOKEN."
        return
      end

      imported = 0
      legislators.each do |leg_data|
        if import_legislator(leg_data)
          imported += 1
        end
      end

      puts "  Done. #{imported} legislators imported/updated."
    end

    private

    def import_legislator(data)
      utah_leg_id = data["id"]&.to_s
      return false if utah_leg_id.blank?

      rep = Representative.find_or_initialize_by(utah_leg_id: utah_leg_id)

      # Determine chamber and position type
      # API returns "H" or "S" in the "house" field
      chamber = data["house"]
      position_type = case chamber&.upcase
      when "S" then :state_senator
      when "H" then :state_representative
      else :state_representative
      end

      chamber_display = position_type == :state_senator ? "Senate" : "House"
      district = data["district"]&.to_s

      title = if position_type == :state_senator
                "State Senator, District #{district}"
              else
                "State Representative, District #{district}"
              end

      # "formatName" is display order ("Thomas W. Peterson")
      # "fullName" is inverted ("Peterson, Thomas W.")
      # Parse first/last from formatName
      first_name, last_name = parse_name(data["formatName"], data["fullName"])

      rep.assign_attributes(
        first_name: first_name,
        last_name: last_name,
        full_name: data["formatName"] || "#{first_name} #{last_name}",
        title: title,
        position_type: position_type,
        level: :state,
        chamber: chamber_display,
        party: normalize_party(data["party"]),
        district: district,
        phone: data["cell"] || data["workPhone"] || data["homePhone"],
        email: data["email"],
        photo_url: data["image"],
        office_address: data["address"],
        active: true
      )

      if rep.save
        puts "  #{rep.display_name}"
        true
      else
        puts "  FAILED: #{first_name} #{last_name} — #{rep.errors.full_messages.join(', ')}"
        false
      end
    end

    # Parses first and last name from the API's name fields.
    # formatName: "Thomas W. Peterson" (display order)
    # fullName: "Peterson, Thomas W." (inverted)
    def parse_name(format_name, full_name)
      # Prefer parsing from inverted fullName ("Last, First Middle")
      if full_name.present? && full_name.include?(",")
        parts = full_name.split(",", 2).map(&:strip)
        last_name = parts[0]
        # First name is everything before the last word (middle names/initials)
        first_parts = parts[1]&.split(" ")
        first_name = first_parts&.first
        return [first_name, last_name]
      end

      # Fallback: parse from formatName ("First Middle Last")
      if format_name.present?
        parts = format_name.split(" ")
        first_name = parts.first
        last_name = parts.last
        return [first_name, last_name]
      end

      [nil, nil]
    end

    def normalize_party(party)
      case party&.downcase&.strip
      when "r", "republican" then "Republican"
      when "d", "democrat", "democratic" then "Democrat"
      when "l", "libertarian" then "Libertarian"
      when "i", "independent" then "Independent"
      else party
      end
    end
  end
end
