require "bard/plugin"

Bard::Plugin.register :deploy do
  cli "Bard::CLI::Deploy", require: "bard/cli/deploy"
end
