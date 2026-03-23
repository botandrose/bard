require "bard/cli/command"
require "bard/command"

class Bard::CLI::Run < Bard::CLI::Command
  option :target, type: :string, default: "production"
  option :home, type: :boolean
  desc "run <command>", "run the given command on the specified target"

  def self.setup cli
    # HACK: we don't use Thor::Base#run, so its okay to stomp on it here
    original_verbose, $VERBOSE = $VERBOSE, nil
    Thor::THOR_RESERVED_WORDS -= ["run"]
    $VERBOSE = original_verbose
    super
  end

  def run *args
    target = config[options[:target].to_sym]
    target.run!(*args.join(" "), verbose: true, home: options[:home])
  rescue Bard::Command::Error => e
    puts red("!!! ") + "Running command failed: #{yellow(e.message)}"
    exit 1
  end
end
