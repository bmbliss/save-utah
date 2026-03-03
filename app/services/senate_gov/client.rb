module SenateGov
  # HTTP client for senate.gov XML vote data.
  # Unlike Congress.gov, this requires NO API key — it's publicly accessible XML.
  #
  # Endpoints:
  #   Vote list:   https://www.senate.gov/legislative/LIS/roll_call_lists/vote_menu_{congress}_{session}.xml
  #   Vote detail: https://www.senate.gov/legislative/LIS/roll_call_votes/vote{congress}{session}/vote_{congress}_{session}_{number}.xml
  #
  # Uses REXML from Ruby stdlib for XML parsing (no additional gems needed).
  class Client
    BASE_URL = "https://www.senate.gov"

    # Fetches the vote menu for a given congress and session.
    # Returns an array of hashes with vote_number, issue, question, result, date.
    def vote_list(congress:, session:)
      url = "#{BASE_URL}/legislative/LIS/roll_call_lists/vote_menu_#{congress}_#{session}.xml"
      xml = fetch_xml(url)
      return [] unless xml

      votes = []
      xml.elements.each("vote_summary/votes/vote") do |vote_el|
        votes << {
          vote_number: text(vote_el, "vote_number"),
          issue: text(vote_el, "issue"),
          question: text(vote_el, "question"),
          result: text(vote_el, "result"),
          date: text(vote_el, "vote_date")
        }
      end

      votes
    end

    # Fetches individual vote detail including member votes.
    # Returns parsed XML document or nil on failure.
    def vote_detail(congress:, session:, number:)
      # Numbers must be 5-digit zero-padded in the URL
      padded = number.to_s.rjust(5, "0")
      url = "#{BASE_URL}/legislative/LIS/roll_call_votes/vote#{congress}#{session}/vote_#{congress}_#{session}_#{padded}.xml"
      fetch_xml(url)
    end

    private

    # Fetches and parses XML from a URL via Faraday.
    def fetch_xml(url)
      response = connection.get(url)
      require "rexml/document"
      REXML::Document.new(response.body)
    rescue Faraday::Error => e
      puts "  [SenateGov::Client] Error fetching #{url}: #{e.message}"
      nil
    rescue REXML::ParseException => e
      puts "  [SenateGov::Client] XML parse error for #{url}: #{e.message}"
      nil
    end

    # Extracts text content from an XML element by child name.
    def text(element, child_name)
      child = element.elements[child_name]
      child&.text&.strip
    end

    def connection
      @connection ||= Faraday.new do |conn|
        conn.headers["User-Agent"] = "SaveUtah/1.0 (civic-engagement-platform)"
        conn.adapter Faraday.default_adapter
      end
    end
  end
end
