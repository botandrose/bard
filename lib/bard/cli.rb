# this file gets loaded in the CLI context, not the Rails boot context

require "thor"
require "bard/config"
require "bard/command"
require "term/ansicolor"

module Bard
  class CLI < Thor
    include Term::ANSIColor

    class_option :verbose, type: :boolean, aliases: :v

    {
      data: "Data",
      stage: "Stage",
      deploy: "Deploy",
      ci: "CI",
      master_key: "MasterKey",
      setup: "Setup",
      run: "Run",
      open: "Open",
      ssh: "SSH",
      install: "Install",
      ping: "Ping",
      hurt: "Hurt",
      vim: "Vim",
    }.each do |command, klass|
      require "bard/cli/#{command}"
      include const_get(klass)
    end

    {
      provision: "Provision",
      new: "New",
    }.each do |command, klass|
      require "bard/cli/#{command}"
      const_get(klass).setup(self)
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
        @project_name ||= File.expand_path(".").split("/").last
      end
    end
  end
end

