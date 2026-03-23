require "bard/plugin"

Bard::Plugin.register :master_key do
  cli "Bard::CLI::MasterKey", require: "bard/cli/master_key"
end
