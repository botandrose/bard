require "net/http"
require "uri"

module Bard
  class Ping < Struct.new(:server)
    def self.call server
      new(server).call
    end

    def call
      server.ping.reject { |url| reachable?(url) }
    end

    private

    def reachable?(url)
      attempts = 0
      begin
        attempts += 1
        response = get_response_with_redirect(url)
        response.is_a?(Net::HTTPSuccess)
      rescue StandardError
        retry if attempts < 2
        false
      end
    end

    def get_response_with_redirect uri_str, limit=5
      uri = URI(uri_str)
      response = http_get(uri)

      case response
      when Net::HTTPRedirection
        if limit == 0
          puts "too many HTTP redirects"
          response
        else
          location = response["location"]
          return response unless location

          next_uri = begin
            uri + location
          rescue URI::InvalidURIError
            URI(location)
          end

          get_response_with_redirect(next_uri, limit - 1)
        end
      else
        response
      end
    end

    def http_get(uri)
      Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: uri.scheme == "https",
        open_timeout: 5,
        read_timeout: 5,
      ) do |http|
        http.get(uri.request_uri)
      end
    end
  end
end
