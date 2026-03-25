require "bard/plugins/ping"
require "bard/plugins/ssh"
require "bard/plugins/git"
require "bard/command"
require "bard/plugins/deploy/strategy"
require "bard/plugins/deploy/ssh_strategy"
require "bard/plugins/deploy/ci"
require "bard/plugins/deploy/ci/jenkins"
require "bard/plugins/deploy/ci/local"
require "bard/plugins/deploy/ci/github_actions"
require "tmpdir"

class Bard::CLI
  option :"skip-ci", type: :boolean
  option :"local-ci", type: :boolean
  option :ci, type: :string
  option :clone, type: :boolean
  option :target, type: :string, default: "production"
  desc "deploy [BRANCH]", "deploys branch to target (default: current branch to production)"
  def deploy(branch = nil)
    branch ||= Bard::Git.current_branch

    if branch == "master"
      if !Bard::Git.up_to_date_with_remote?(branch)
        run! "git push origin #{branch}:#{branch}"
      end
      invoke :ci, [branch], options.slice("local-ci", "ci") unless options["skip-ci"] || config.ci == false

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

      invoke :ci, [branch], options.slice("local-ci", "ci") unless options["skip-ci"] || config.ci == false

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
      target = config[to]
      strategy = target.deploy_strategy_instance
      strategy.deploy
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

  desc "stage [branch=HEAD]", "pushes current branch, and stages it"
  def stage(branch = Bard::Git.current_branch)
    unless config.targets.key?(:production)
      raise Thor::Error.new("`bard stage` is disabled until a production target is defined. Until then, please use `bard deploy` to deploy to the staging target.")
    end

    run! "git push -u origin #{branch}", verbose: true

    target = config[:staging]
    strategy = target.deploy_strategy_instance
    strategy.deploy

    puts green("Stage Succeeded")

    ping :staging
  rescue Bard::Command::Error => e
    puts red("!!! ") + "Running command failed: #{yellow(e.message)}"
    exit 1
  end

  option :"local-ci", type: :boolean
  option :ci, type: :string
  option :status, type: :boolean
  option :resume, type: :boolean
  desc "ci [branch=HEAD]", "runs ci against BRANCH"
  def ci(branch = Bard::Git.current_branch)
    runner_name = if options["local-ci"]
      :local
    elsif options["ci"]
      options["ci"].to_sym
    else
      config.ci
    end
    ci = Bard::CI.new(project_name, branch, runner_name: runner_name)
    unless ci.exists?
      puts red("No CI found for #{project_name}!")
      puts "Re-run with --skip-ci to bypass CI, if you absolutely must, and know what you're doing."
      exit 1
    end

    return puts ci.status if options["status"]

    if options["resume"]
      puts "Continuous integration: resuming build..."
      success = ci.resume do |elapsed_time, last_time|
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
    else
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
    end

    if success
      puts
      puts "Continuous integration: success!"
    else
      puts
      puts ci.console
      puts red("Automated tests failed!")
      exit 1
    end
  end

  option :from, default: "production"
  option :to, default: "local"
  desc "master_key --from=production --to=local", "copy master key from from to to"
  def master_key
    from = config[options[:from]]
    to = config[options[:to]]
    from.copy_file "config/master.key", to:
  end
end

require "bard/config"

class Bard::Config
  def ci(system = nil)
    if system.nil?
      @ci_system
    else
      @ci_system = system
    end
  end
end

require "bard/target"

class Bard::Target
  def deploy_strategy
    @deploy_strategy
  end

  def deploy_strategy_instance
    strategy = @deploy_strategy
    strategy ||= :ssh if has_capability?(:ssh)
    raise "No deployment strategy configured for target #{key}" unless strategy

    strategy_class = Bard::DeployStrategy[strategy]
    raise "Unknown deployment strategy: #{strategy}" unless strategy_class

    strategy_class.new(self)
  end

  def strategy_options(strategy_name)
    @strategy_options_hash ||= {}
    @strategy_options_hash[strategy_name] || {}
  end
end
