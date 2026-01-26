require "bard/plugin"

Bard::Plugin.register :install do
  cli "Bard::CLI::Install", require: "bard/cli/install"
end
