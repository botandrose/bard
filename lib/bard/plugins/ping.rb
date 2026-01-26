require "bard/plugin"

Bard::Plugin.register :ping do
  cli "Bard::CLI::Ping", require: "bard/cli/ping"
  cli "Bard::CLI::Open", require: "bard/cli/open"
end
