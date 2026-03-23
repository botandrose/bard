require "bard/plugin"

Bard::Plugin.register :ssh do
  cli "Bard::CLI::SSH", require: "bard/cli/ssh"
end
