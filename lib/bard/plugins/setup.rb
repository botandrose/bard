require "bard/plugin"

Bard::Plugin.register :setup do
  cli "Bard::CLI::Setup", require: "bard/cli/setup"
end
