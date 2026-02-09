require "bard/command"

module Bard::CLI::Run
  def self.included mod
    mod.class_eval do

      # HACK: we don't use Thor::Base#run, so its okay to stomp on it here
      original_verbose, $VERBOSE = $VERBOSE, nil
      Thor::THOR_RESERVED_WORDS -= ["run"]
      $VERBOSE = original_verbose

      option :target, type: :string, default: "production"
      desc "run <command>", "run the given command on the specified target"
      def run *args
        target = config[options[:target].to_sym]
        target.run! *args.join(" "), verbose: true
      rescue Bard::Command::Error => e
        puts red("!!! ") + "Running command failed: #{yellow(e.message)}"
        exit 1
      end

    end
  end
end

