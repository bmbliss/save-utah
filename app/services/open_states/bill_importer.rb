module OpenStates
  # Imports Utah bills from the OpenStates API as a supplementary data source.
  class BillImporter
    def initialize
      @client = Client.new
    end

    def import(session: nil, pages: 3)
      puts "Importing Utah bills from OpenStates..."

      total_imported = 0
      (1..pages).each do |page|
        bills_data = @client.utah_bills(session: session, page: page)
        break if bills_data.empty?

        bills_data.each do |bill_data|
          if import_bill(bill_data)
            total_imported += 1
          end
        end
      end

      puts "  Done. #{total_imported} bills imported/updated."
    end

    private

    def import_bill(data)
      openstates_id = data["id"]
      return false if openstates_id.blank?

      identifier = data["identifier"]
      return false if identifier.blank?

      # Don't overwrite bills we got from primary sources
      existing = Bill.find_by(bill_number: identifier, data_source: ["congress_gov", "utah_legislature"])
      if existing
        # Just update the openstates_id for cross-referencing
        existing.update(openstates_bill_id: openstates_id) if existing.openstates_bill_id.blank?
        return false
      end

      bill = Bill.find_or_initialize_by(openstates_bill_id: openstates_id)

      # Determine level and chamber
      jurisdiction = data.dig("jurisdiction", "name") || data.dig("jurisdiction_id")
      level = jurisdiction&.include?("United States") ? :federal : :state

      # v3 uses snake_case: from_organization
      from_org = data.dig("from_organization", "classification") || data.dig("fromOrganization", "classification")
      chamber = case from_org&.downcase
      when "upper", "senate" then "Senate"
      when "lower", "house" then "House"
      else nil
      end

      # v3 uses snake_case: legislative_session
      session_data = data["session"] || data["legislative_session"] || data["legislativeSession"]
      session_name = session_data.is_a?(Hash) ? session_data["name"] : session_data

      bill.assign_attributes(
        title: data["title"] || "Untitled Bill",
        bill_number: identifier,
        summary: data["abstract"]&.first,
        level: level,
        chamber: chamber,
        session_year: extract_year(session_name),
        session_name: session_name,
        # v3 uses snake_case: latest_action_date
        last_action_on: parse_date(data["latest_action_date"] || data["latestActionDate"]),
        data_source: "openstates"
      )

      if bill.save
        puts "  #{bill.bill_number}: #{bill.title.truncate(60)}"
        true
      else
        puts "  FAILED: #{identifier} — #{bill.errors.full_messages.join(', ')}"
        false
      end
    end

    def extract_year(session_name)
      return Date.today.year if session_name.blank?
      match = session_name.to_s.match(/(\d{4})/)
      match ? match[1].to_i : Date.today.year
    end

    def parse_date(date_string)
      return nil if date_string.blank?
      Date.parse(date_string)
    rescue Date::Error
      nil
    end
  end
end
