require "bard/cli/command"

class Bard::CLI::SSH < Bard::CLI::Command
  option :home, type: :boolean
  desc "ssh [to=production]", "logs into the specified server via SSH"
  def ssh to=:production
    config[to].exec! "exec $SHELL -l", home: options[:home]
  end
end
