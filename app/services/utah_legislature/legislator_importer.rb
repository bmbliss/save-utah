module UtahLegislature
  # Imports state legislators from the Utah Legislature API.
  # Maps Utah Legislature data to our Representative model.
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
      utah_leg_id = (data["id"] || data["legislatorId"])&.to_s
      return false if utah_leg_id.blank?

      rep = Representative.find_or_initialize_by(utah_leg_id: utah_leg_id)

      # Determine chamber and position type
      chamber = data["house"] || data["chamber"]
      position_type = case chamber&.downcase
      when "senate", "s" then :state_senator
      when "house", "h", "house of representatives" then :state_representative
      else :state_representative
      end

      chamber_display = position_type == :state_senator ? "Senate" : "House"
      district = data["district"]&.to_s

      title = if position_type == :state_senator
                "State Senator, District #{district}"
              else
                "State Representative, District #{district}"
              end

      first_name = data["firstName"] || data["first"]
      last_name = data["lastName"] || data["last"]

      rep.assign_attributes(
        first_name: first_name,
        last_name: last_name,
        full_name: "#{first_name} #{last_name}",
        title: title,
        position_type: position_type,
        level: :state,
        chamber: chamber_display,
        party: normalize_party(data["party"]),
        district: district,
        phone: data["phone"],
        email: data["email"],
        website_url: data["webPage"] || data["website"],
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
