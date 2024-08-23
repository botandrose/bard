module Bard::CLI::SSH
  def self.included mod
    mod.class_eval do

      option :home, type: :boolean
      desc "ssh [to=production]", "logs into the specified server via SSH"
      def ssh to=:production
        config[to].exec! "exec $SHELL -l", home: options[:home]
      end

    end
  end
end

