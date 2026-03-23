require "bard/plugin"

Bard::Plugin.register :data do
  cli "Bard::CLI::Data", require: "bard/cli/data"
end
