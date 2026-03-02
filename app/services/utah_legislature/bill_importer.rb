module UtahLegislature
  # Imports state bills from the Utah Legislature API.
  #
  # The bill list endpoint returns sparse data (number, trackingID, updatetime,
  # lastActionTime only). A detail call is needed for each bill to get:
  #   shortTitle, generalProvisions, lastAction, lastActionDate,
  #   primeSponsorName, actionHistoryList, billVersionList, etc.
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

      puts "  Found #{bills_data.size} bills. Fetching details..."

      imported = 0
      bills_data.each do |list_data|
        bill_number = list_data["number"]
        next if bill_number.blank?

        begin
          detail = @client.bill(session, bill_number)
          next unless detail

          if import_bill(detail, session)
            imported += 1
          end
        rescue ApiClient::ApiError => e
          puts "  Error fetching detail for #{bill_number}: #{e.message}"
        end
      end

      puts "  Done. #{imported} bills imported/updated out of #{bills_data.size} fetched."
    end

    private

    def import_bill(data, session)
      bill_number = data["billNumber"] || data["number"]
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
      year_match = session.match(/(\d{4})/)
      session_year = year_match ? year_match[1].to_i : Date.today.year

      # Find the introduced bill doc URL if available
      full_text_url = find_bill_text_url(data)

      bill.assign_attributes(
        title: data["shortTitle"].presence || "Untitled Bill",
        bill_number: bill_number,
        summary: data["generalProvisions"],
        status: data["lastAction"],
        level: :state,
        chamber: chamber,
        session_year: session_year,
        session_name: session_name_for(session),
        last_action_on: parse_date(data["lastActionDate"]),
        full_text_url: full_text_url,
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

    # Extracts the bill text URL from billVersionList
    def find_bill_text_url(data)
      versions = data["billVersionList"]
      return nil unless versions.is_a?(Array)

      # Look through bill docs for the introduced or enrolled XML
      versions.each do |version|
        docs = version["billDocs"]
        next unless docs.is_a?(Array)

        # Prefer enrolled, then introduced
        enrolled = docs.find { |d| d["fileType"] == "Enrolled" && d["url"].present? }
        return "https://le.utah.gov#{enrolled['url']}" if enrolled

        introduced = docs.find { |d| d["fileType"] == "Introduced" && d["url"].present? }
        return "https://le.utah.gov#{introduced['url']}" if introduced
      end

      nil
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
