require "bard/plugin"

Bard::Plugin.register :provision do
  cli "Bard::CLI::Provision", require: "bard/cli/provision"
end
