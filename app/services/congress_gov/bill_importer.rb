module CongressGov
  # Imports federal bills from the Congress.gov API.
  # Focuses on bills relevant to Utah (sponsored by Utah delegation or Utah-related).
  class BillImporter
    def initialize
      @client = Client.new
    end

    def import(congress: 119, limit: 250)
      puts "Importing federal bills from Congress.gov (Congress #{congress})..."
      bills_data = @client.bills(congress: congress, limit: limit)

      if bills_data.empty?
        puts "  No bills returned. Check your CONGRESS_GOV_API_KEY."
        return
      end

      imported = 0
      bills_data.each do |bill_data|
        if import_bill(bill_data, congress)
          imported += 1
        end
      end

      puts "  Done. #{imported} bills imported/updated out of #{bills_data.size} fetched."
    end

    private

    def import_bill(data, congress)
      bill_type = data["type"]&.downcase   # "hr", "s", "hjres", etc.
      number = data["number"]
      return false if bill_type.blank? || number.blank?

      congress_bill_id = "#{congress}-#{bill_type}-#{number}"
      bill_number = "#{bill_type.upcase} #{number}"

      bill = Bill.find_or_initialize_by(congress_bill_id: congress_bill_id)

      chamber = case bill_type
      when "s", "sres", "sjres", "sconres" then "Senate"
      when "hr", "hres", "hjres", "hconres" then "House"
      else nil
      end

      bill.assign_attributes(
        title: data["title"] || "Untitled Bill",
        bill_number: bill_number,
        summary: data["latestAction"]&.dig("text"),
        status: data.dig("latestAction", "text")&.truncate(100),
        level: :federal,
        chamber: chamber,
        session_year: Date.today.year,
        session_name: "#{congress}th Congress",
        introduced_on: parse_date(data["introducedDate"]),
        last_action_on: parse_date(data.dig("latestAction", "actionDate")),
        data_source: "congress_gov"
      )

      if bill.save
        puts "  #{bill.bill_number}: #{bill.title.truncate(60)}"
        true
      else
        puts "  FAILED: #{bill_number} — #{bill.errors.full_messages.join(', ')}"
        false
      end
    end

    def parse_date(date_string)
      return nil if date_string.blank?
      Date.parse(date_string)
    rescue Date::Error
      nil
    end
  end
end
