require "bard/plugin"

Bard::Plugin.register :hurt do
  cli "Bard::CLI::Hurt", require: "bard/cli/hurt"
end
