require "bard/plugin"
require "bard/cli/command"
require "bard/plugins/ping/target_methods"

class Bard::CLI::Ping < Bard::CLI::Command
  desc "ping [target=production]", "hits the target over http to verify that its up."
  def ping target=:production
    down_urls = Bard::Ping.call(config[target])
    down_urls.each { |url| puts "#{url} is down!" }
    exit 1 if down_urls.any?
  end
end

Bard::Plugin.register :ping do
  cli Bard::CLI::Ping
end
