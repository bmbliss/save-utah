# Base class for all external API clients.
# Provides shared Faraday HTTP logic, error handling, and rate limiting awareness.
class ApiClient
  class ApiError < StandardError; end
  class RateLimitError < ApiError; end
  class NotFoundError < ApiError; end

  # Override in subclasses
  def base_url
    raise NotImplementedError, "Subclass must define #base_url"
  end

  private

  # Builds a Faraday connection with default settings.
  # Subclasses can override #connection_options to add headers, params, etc.
  def connection
    @connection ||= Faraday.new(url: base_url) do |conn|
      conn.headers["User-Agent"] = "SaveUtah/1.0 (civic-engagement-platform)"
      conn.request :url_encoded
      conn.response :json, content_type: /\bjson$/
      conn.response :raise_error
      conn.adapter Faraday.default_adapter

      # Apply subclass-specific options (auth headers, params, etc.)
      configure_connection(conn)
    end
  end

  # Hook for subclasses to add auth, custom headers, etc.
  def configure_connection(conn)
    # Override in subclasses
  end

  # Makes a GET request and returns parsed response body.
  # Retries up to MAX_RETRIES times on rate limit (429) with exponential backoff.
  MAX_RETRIES = 3

  def get(path, params = {})
    retries = 0

    begin
      response = connection.get(path, params)
      response.body
    rescue Faraday::TooManyRequestsError => e
      retries += 1
      if retries <= MAX_RETRIES
        wait = 2**retries  # 2s, 4s, 8s
        log("Rate limited. Waiting #{wait}s before retry #{retries}/#{MAX_RETRIES}...")
        sleep(wait)
        retry
      end
      raise RateLimitError, "Rate limit exceeded after #{MAX_RETRIES} retries: #{e.message}"
    rescue Faraday::ResourceNotFound => e
      raise NotFoundError, "Resource not found: #{path}"
    rescue Faraday::Error => e
      # Extract response body for better debugging of API errors
      body = e.respond_to?(:response) && e.response.is_a?(Hash) ? e.response[:body] : nil
      detail = body ? " — Response: #{body}" : ""
      raise ApiError, "API request failed: #{e.message}#{detail}"
    end
  end

  # Logs import progress to stdout (visible in rake task output)
  def log(message)
    puts "  [#{self.class.name}] #{message}"
  end
end
