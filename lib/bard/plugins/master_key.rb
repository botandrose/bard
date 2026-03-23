require "bard/plugin"
require "bard/cli/command"

class Bard::CLI::MasterKey < Bard::CLI::Command
  option :from, default: "production"
  option :to, default: "local"
  desc "master_key --from=production --to=local", "copy master key from from to to"
  def master_key
    from = config[options[:from]]
    to = config[options[:to]]
    from.copy_file "config/master.key", to:
  end
end

Bard::Plugin.register :master_key do
  cli Bard::CLI::MasterKey
end
