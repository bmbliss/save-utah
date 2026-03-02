module OpenStates
  # Imports Utah legislators from the OpenStates API as a supplementary data source.
  # Primarily used to fill in gaps or as a fallback when the Utah Legislature API is unavailable.
  class PeopleImporter
    def initialize
      @client = Client.new
    end

    def import
      puts "Importing Utah legislators from OpenStates..."

      people = @client.utah_people
      if people.empty?
        puts "  No people returned. Check your OPENSTATES_API_KEY."
        return
      end

      imported = 0
      people.each do |person_data|
        if import_person(person_data)
          imported += 1
        end
      end

      puts "  Done. #{imported} legislators imported/updated."
    end

    private

    def import_person(data)
      openstates_id = data["id"]
      return false if openstates_id.blank?

      # Try to match by openstates_id first, then by name
      rep = Representative.find_by(openstates_id: openstates_id)
      rep ||= Representative.find_by(
        first_name: data["givenName"] || data["given_name"],
        last_name: data["familyName"] || data["family_name"],
        level: :state
      )
      rep ||= Representative.new(openstates_id: openstates_id)

      # Determine position type
      current_role = data.dig("currentRole") || {}
      org_classification = current_role["orgClassification"] || data.dig("current_role", "org_classification")

      position_type = case org_classification&.downcase
      when "upper", "senate" then :state_senator
      when "lower", "house" then :state_representative
      else :state_representative
      end

      chamber = position_type == :state_senator ? "Senate" : "House"
      district = current_role["district"] || data.dig("current_role", "district")
      first_name = data["givenName"] || data["given_name"]
      last_name = data["familyName"] || data["family_name"]

      rep.assign_attributes(
        first_name: first_name,
        last_name: last_name,
        full_name: data["name"] || "#{first_name} #{last_name}",
        title: position_type == :state_senator ? "State Senator, District #{district}" : "State Representative, District #{district}",
        position_type: position_type,
        level: :state,
        chamber: chamber,
        party: normalize_party(data["party"] || data.dig("primaryParty")),
        district: district&.to_s,
        photo_url: data["image"],
        openstates_id: openstates_id,
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
      when "republican" then "Republican"
      when "democratic", "democrat" then "Democrat"
      when "libertarian" then "Libertarian"
      when "independent" then "Independent"
      else party
      end
    end
  end
end
