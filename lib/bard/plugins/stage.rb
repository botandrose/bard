require "bard/plugin"

Bard::Plugin.register :stage do
  cli "Bard::CLI::Stage", require: "bard/cli/stage"
end
