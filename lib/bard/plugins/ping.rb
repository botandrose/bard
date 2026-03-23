require "bard/plugin"
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

class Bard::CLI::Open < Bard::CLI::Command
  desc "open [server=production]", "opens the url in the web browser."
  def open server=:production
    exec "xdg-open #{open_url server}"
  end

  private

  def open_url server
    if server.to_sym == :ci
      "https://github.com/botandrosedesign/#{project_name}/actions/workflows/ci.yml"
    else
      config[server].ping.first
    end
  end
end

Bard::Plugin.register :ping do
  cli Bard::CLI::Ping
  cli Bard::CLI::Open
end
