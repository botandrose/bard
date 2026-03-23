require "bard/plugin"

class Bard::CLI::SSH < Bard::Plugin::Command
  option :home, type: :boolean
  desc "ssh [to=production]", "logs into the specified server via SSH"
  def ssh to=:production
    config[to].exec! "exec $SHELL -l", home: options[:home]
  end
end

Bard::Plugin.register :ssh do
  cli Bard::CLI::SSH
end
