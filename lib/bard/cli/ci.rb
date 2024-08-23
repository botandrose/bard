require "bard/ci"
require "bard/git"

module Bard::CLI::CI
  def self.included mod
    mod.class_eval do

      option :"local-ci", type: :boolean
      option :status, type: :boolean
      desc "ci [branch=HEAD]", "runs ci against BRANCH"
      def ci branch=Bard::Git.current_branch
        ci = Bard::CI.new(project_name, branch, local: options["local-ci"])
        if ci.exists?
          return puts ci.status if options["status"]

          puts "Continuous integration: starting build on #{branch}..."

          success = ci.run do |elapsed_time, last_time|
            if last_time
              percentage = (elapsed_time.to_f / last_time.to_f * 100).to_i
              output = "  Estimated completion: #{percentage}%"
            else
              output = "  No estimated completion time. Elapsed time: #{elapsed_time} sec"
            end
            print "\x08" * output.length
            print output
            $stdout.flush
          end

          if success
            puts
            puts "Continuous integration: success!"
            puts "Deploying..."
          else
            puts
            puts ci.console
            puts red("Automated tests failed!")
            exit 1
          end

        else
          puts red("No CI found for #{project_name}!")
          puts "Re-run with --skip-ci to bypass CI, if you absolutely must, and know what you're doing."
          exit 1
        end
      end

    end
  end
end

