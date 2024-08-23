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
      provision: "Provision",
      ping: "Ping",
      hurt: "Hurt",
      vim: "Vim",
    }.each do |command, klass|
      require "bard/cli/#{command}"
      include const_get(klass)
    end

    def self.exit_on_failure? = true

    private

    def config
      @config ||= Bard::Config.new(project_name, path: "bard.rb")
    end

    def project_name
      @project_name ||= File.expand_path(".").split("/").last
    end

    def run!(...)
      Bard::Command.run!(...)
    rescue Bard::Command::Error => e
      puts red("!!! ") + "Running command failed: #{yellow(e.message)}"
      exit 1
    end
  end
end

