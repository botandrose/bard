require "bard/plugins/ssh/target_methods"

class Bard::CLI
  option :home, type: :boolean
  desc "ssh [to=production]", "logs into the specified server via SSH"
  def ssh(to = :production)
    config[to].exec! "exec $SHELL -l", home: options[:home]
  end
end
