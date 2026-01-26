require "bard/cli/command"
require "bard/ping"

class Bard::CLI::Ping < Bard::CLI::Command
  desc "ping [server=production]", "hits the server over http to verify that its up."
  def ping server=:production
    server = config[server]
    down_urls = Bard::Ping.call(config[server])
    down_urls.each { |url| puts "#{url} is down!" }
    exit 1 if down_urls.any?
  end
end
