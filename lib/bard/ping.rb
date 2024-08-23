require "net/http"
require "uri"

module Bard
  class Ping < Struct.new(:server)
    def self.call server
      new(server).call
    end

    def call
      server.ping.reject do |url|
        response = get_response_with_redirect(url) rescue nil
        response.is_a?(Net::HTTPSuccess)
      end
    end

    private

    def get_response_with_redirect uri_str, limit=5
      response = Net::HTTP.get_response(URI(uri_str))

      case response
      when Net::HTTPRedirection
        if limit == 0
          puts "too many HTTP redirects"
          response
        else
          get_response_with_redirect(response["location"], limit - 1)
        end
      else
        response
      end
    end
  end
end
