require "bard/plugin"

Bard::Plugin.register :run do
  cli "Bard::CLI::Run", require: "bard/cli/run"
end
