require "bard/ping"

module Bard::CLI::Ping
  def self.included mod
    mod.class_eval do

      desc "ping [server=production]", "hits the server over http to verify that its up."
      def ping server=:production
        server = config[server]
        down_urls = Bard::Ping.call(config[server])
        down_urls.each { |url| puts "#{url} is down!" }
        exit 1 if down_urls.any?
      end

    end
  end
end

