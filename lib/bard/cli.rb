# this file gets loaded in the CLI context, not the Rails boot context

require "thor"
require "bard/version"
require "bard/config"
require "bard/command"
require "term/ansicolor"

module Bard
  class CLI < Thor
    include Term::ANSIColor

    class_option :verbose, type: :boolean, aliases: :v

    map "--version" => :version
    desc "version", "Display version"
    def version
      puts Bard::VERSION
    end

    def self.exit_on_failure? = true

    no_commands do
      def run!(...)
        Bard::Command.run!(...)
      rescue Bard::Command::Error => e
        puts red("!!! ") + "Running command failed: #{yellow(e.message)}"
        exit 1
      end

      def config
        @config ||= Bard::Config.current
      end

      def project_name
        config.project_name
      end
    end

    # load builtin plugins
    Dir[File.join(__dir__, "plugins", "*.rb")].sort.each { |f| require f }

    # load external plugins
    Dir[File.join(Dir.pwd, "lib", "bard", "plugins", "*.rb")].sort.each { |f| require f }

    # load gem-based plugins (e.g., bard-new)
    Gem.find_files("bard/*/plugin.rb").each { |path| require path }
  end
end
