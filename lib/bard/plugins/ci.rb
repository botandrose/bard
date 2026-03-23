require "bard/plugin"

Bard::Plugin.register :ci do
  cli "Bard::CLI::CI", require: "bard/cli/ci"
end
