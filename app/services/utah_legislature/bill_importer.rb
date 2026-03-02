module UtahLegislature
  # Imports state bills from the Utah Legislature API.
  class BillImporter
    def initialize
      @client = Client.new
    end

    def import(session: "2025GS")
      puts "Importing state bills from Utah Legislature API (session: #{session})..."
      bills_data = @client.bills(session: session)

      if bills_data.empty?
        puts "  No bills returned. Check your UTAH_LEGISLATURE_TOKEN."
        return
      end

      imported = 0
      bills_data.each do |bill_data|
        if import_bill(bill_data, session)
          imported += 1
        end
      end

      puts "  Done. #{imported} bills imported/updated out of #{bills_data.size} fetched."
    end

    private

    def import_bill(data, session)
      bill_number = data["number"] || data["billNumber"]
      return false if bill_number.blank?

      utah_bill_id = "#{session}-#{bill_number}"
      bill = Bill.find_or_initialize_by(utah_bill_id: utah_bill_id)

      # Determine chamber from bill number prefix
      chamber = case bill_number
      when /^HB|^HJR|^HCR/ then "House"
      when /^SB|^SJR|^SCR/ then "Senate"
      else nil
      end

      # Parse session year from session code
      session_year = session.match(/(\d{4})/)?.[](1)&.to_i || Date.today.year

      bill.assign_attributes(
        title: data["shortTitle"] || data["title"] || "Untitled Bill",
        bill_number: bill_number,
        summary: data["generalProvisions"] || data["summary"],
        status: data["lastAction"] || data["status"],
        level: :state,
        chamber: chamber,
        session_year: session_year,
        session_name: session_name_for(session),
        introduced_on: parse_date(data["introducedDate"]),
        last_action_on: parse_date(data["lastActionDate"]),
        full_text_url: data["textUrl"] || data["url"],
        data_source: "utah_legislature"
      )

      if bill.save
        puts "  #{bill.bill_number}: #{bill.title.truncate(60)}"
        true
      else
        puts "  FAILED: #{bill_number} — #{bill.errors.full_messages.join(', ')}"
        false
      end
    end

    def session_name_for(session)
      case session
      when /GS$/ then "#{session.match(/\d{4}/)[0]} General Session"
      when /S\d+$/ then "#{session.match(/\d{4}/)[0]} Special Session"
      else session
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
