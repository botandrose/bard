require "bard/plugin"

Bard::Plugin.register :new do
  cli "Bard::CLI::New", require: "bard/cli/new"
end
