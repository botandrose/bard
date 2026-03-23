# this file gets loaded in the CLI context, not the Rails boot context

require "thor"
require "bard/version"
require "bard/config"
require "bard/command"
require "bard/ping"
require "bard/plugin"
require "term/ansicolor"

module Bard
  class CLI < Thor
    include Term::ANSIColor

    class_option :verbose, type: :boolean, aliases: :v

    desc "ping [target=production]", "hits the target over http to verify that its up."
    def ping target=:production
      down_urls = Bard::Ping.call(config[target])
      down_urls.each { |url| puts "#{url} is down!" }
      exit 1 if down_urls.any?
    end

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
        @config ||= Bard::Config.new(project_name, path: "bard.rb")
      end

      def project_name
        @project_name ||= begin
          git_common_dir = `git rev-parse --git-common-dir 2>/dev/null`.chomp
          if $?.success? && !git_common_dir.empty?
            File.basename(File.dirname(File.expand_path(git_common_dir)))
          else
            File.basename(File.expand_path("."))
          end
        end
      end
    end

    Plugin.load!(self)
  end
end
