require "bard/plugin"
require "bard/plugins/ping/target_methods"

class Bard::CLI::Ping < Bard::Plugin::Command
  desc "ping [target=production]", "hits the target over http to verify that its up."
  def ping target=:production
    down_urls = Bard::Ping.call(config[target])
    down_urls.each { |url| puts "#{url} is down!" }
    exit 1 if down_urls.any?
  end
end

