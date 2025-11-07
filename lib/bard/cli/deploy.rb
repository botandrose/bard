require "bard/git"
require "bard/command"
require "bard/github_pages"

module Bard::CLI::Deploy
  def self.included mod
    mod.class_eval do

      option :"skip-ci", type: :boolean
      option :"local-ci", type: :boolean
      option :clone, type: :boolean
      desc "deploy [TO=production]", "checks that current branch is a ff with master, checks with ci, merges into master, deploys to target, and then deletes branch."
      def deploy to=:production
        branch = Bard::Git.current_branch

        if branch == "master"
          if !Bard::Git.up_to_date_with_remote?(branch)
            run! "git push origin #{branch}:#{branch}"
          end
          invoke :ci, [branch], options.slice("local-ci") unless options["skip-ci"]

        else
          run! "git fetch origin master:master"

          unless Bard::Git.fast_forward_merge?("origin/master", branch)
            puts "The master branch has advanced. Attempting rebase..."
            run! "git rebase origin/master"
          end

          run! "git push -f origin #{branch}:#{branch}"

          invoke :ci, [branch], options.slice("local-ci") unless options["skip-ci"]

          run! "git push origin #{branch}:master"
          run! "git fetch origin master:master"
        end

        if `git remote` =~ /\bgithub\b/
          run! "git push github"
        end

        if options[:clone]
          config[to].run! "git clone git@github.com:botandrosedesign/#{project_name} #{config[to].path}", home: true
          invoke :master_key, [], from: "local", to: to
          config[to].run! "bin/setup && bard setup"
        else
          # Use deployment strategy
          target = config[to]
          if target.deploy_strategy
            require "bard/deploy_strategy/#{target.deploy_strategy}"
            strategy = target.deploy_strategy_instance
            strategy.deploy
          else
            # Fallback to default SSH deployment if no strategy configured
            target.run! "git pull origin master && bin/setup"
          end
        end

        puts green("Deploy Succeeded")

        if branch != "master"
          puts "Deleting branch: #{branch}"
          run! "git push --delete origin #{branch}"

          if branch == Bard::Git.current_branch
            run! "git checkout master"
          end

          run! "git branch -D #{branch}"
        end

        ping to
      rescue Bard::Command::Error => e
        puts red("!!! ") + "Running command failed: #{yellow(e.message)}"
        exit 1
      end

    end
  end
end

