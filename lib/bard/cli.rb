# this file gets loaded in the CLI context, not the Rails boot context

require "thor"
require "bard/version"
require "bard/config"
require "bard/command"

module Bard
  class CLI < Thor
    class_option :verbose, type: :boolean, aliases: :v

    map "--version" => :version
    desc "version", "Display version"
    def version
      puts Bard::VERSION
    end

    def self.exit_on_failure? = true

    no_commands do
      def red(text)    = "\e[31m#{text}\e[0m"
      def yellow(text) = "\e[33m#{text}\e[0m"
      def green(text)  = "\e[32m#{text}\e[0m"

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

    # load plugins from bard and other gems
    Gem.find_files("bard/plugins/*.rb").sort.each { |path| require path }
  end
end
