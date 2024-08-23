require "bard/git"
require "bard/command"

module Bard::CLI::Stage
  def self.included mod
    mod.class_eval do

      desc "stage [branch=HEAD]", "pushes current branch, and stages it"
      def stage branch=Bard::Git.current_branch
        unless config.servers.key?(:production)
          raise Thor::Error.new("`bard stage` is disabled until a production server is defined. Until then, please use `bard deploy` to deploy to the staging server.")
        end

        run! "git push -u origin #{branch}", verbose: true
        config[:staging].run! "git fetch && git checkout -f origin/#{branch} && bin/setup"
        puts green("Stage Succeeded")

        ping :staging
      rescue Bard::Command::Error => e
        puts red("!!! ") + "Running command failed: #{yellow(e.message)}"
        exit 1
      end

    end
  end
end

