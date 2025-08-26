require "bard/git"
require "bard/command"
require "bard/github_pages"
require "tmpdir"

module Bard::CLI::Deploy
  def self.included mod
    mod.class_eval do

      option :"skip-ci", type: :boolean
      option :"local-ci", type: :boolean
      option :clone, type: :boolean
      option :target, type: :string, default: "production"
      desc "deploy [BRANCH]", "deploys branch to target (default: current branch to production)"
      def deploy branch=nil
        branch ||= Bard::Git.current_branch

        if branch == "master"
          if !Bard::Git.up_to_date_with_remote?(branch)
            run! "git push origin #{branch}:#{branch}"
          end
          invoke :ci, [branch], options.slice("local-ci") unless options["skip-ci"]

        else
          run! "git fetch origin"
          if Bard::Git.current_branch != "master"
            run! "git fetch origin master:master"
          end

          unless Bard::Git.fast_forward_merge?("origin/master", branch)
            puts "The master branch has advanced. Attempting rebase..."
            if branch == Bard::Git.current_branch
              run! "git rebase origin/master"
            else
              tmpdir = Dir.mktmpdir("bard-rebase")
              begin
                run! "git worktree add --detach #{tmpdir} #{branch}"
                success = Dir.chdir(tmpdir) { system("git rebase origin/master") }
                rebased_sha = Dir.chdir(tmpdir) { `git rev-parse HEAD`.strip } if success
                run! "git worktree remove #{tmpdir} --force"
                unless success
                  puts red("!!! ") + "Rebase failed due to conflicts."
                  puts "Please rebase #{branch} manually:"
                  puts "  git checkout #{branch}"
                  puts "  git rebase origin/master"
                  exit 1
                end
                run! "git branch -f #{branch} #{rebased_sha}"
              ensure
                FileUtils.rm_rf(tmpdir) if Dir.exist?(tmpdir)
              end
            end
          end

          run! "git push -f origin #{branch}:#{branch}"

          invoke :ci, [branch], options.slice("local-ci") unless options["skip-ci"]

          run! "git push origin #{branch}:master"
          if Bard::Git.current_branch != "master"
            run! "git fetch origin master:master"
          else
            run! "git pull origin master"
          end
        end

        if `git remote` =~ /\bgithub\b/
          run! "git push github"
        end

        to = options[:target].to_sym

        if options[:clone]
          config[to].run! "git clone git@github.com:botandrosedesign/#{project_name} #{config[to].path}", home: true
          invoke :master_key, [], from: "local", to: to
          config[to].run! "bin/setup && bard setup"
        else
          # Use deployment strategy for v2.0 Targets, or fallback for v1.x Servers
          target = config[to]
          if target.respond_to?(:deploy_strategy) && target.deploy_strategy
            require "bard/deploy_strategy/#{target.deploy_strategy}"
            strategy = target.deploy_strategy_instance
            strategy.deploy
          elsif target.respond_to?(:github_pages) && target.github_pages
            # Old v1.x github_pages support
            require "bard/github_pages"
            Bard::GithubPages.new(self).deploy(target)
          else
            # Default SSH deployment
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

