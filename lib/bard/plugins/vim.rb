require "bard/plugin"

Bard::Plugin.register :vim do
  cli "Bard::CLI::Vim", require: "bard/cli/vim"
end
