module Bard; end

require "bard/base"
require "bard/git"
require "bard/ci"
require "bard/data"

require "bard/config"

class Bard::CLI < Thor
  def initialize(*args, **kwargs, &block)
    super
    @config = Config.new(project_name, "bard.rb")
  end

  desc "data [FROM=production, TO=local]", "copy database and assets from FROM to TO"
  def data(from=nil, to="local")
    from ||= @config.servers.key?(:production) ? "production" : "staging"
    Data.new(self, from, to).call
  end

  method_options %w( verbose -v ) => :boolean
  desc "stage [BRANCH=HEAD]", "pushes current branch, and stages it"
  def stage branch=Git.current_branch
    unless @config.servers.key?(:production)
      raise Thor::Error.new("`bard stage` is disabled until a production server is defined. Until then, please use `bard deploy` to deploy to the staging server.")
    end

    run_crucial "git push -u origin #{branch}", true
    command = "git fetch && git checkout -f origin/#{branch} && bin/setup"
    run_crucial ssh_command(:staging, command)
    puts green("Stage Succeeded")

    ping :staging
  end

  method_options %w[verbose -v] => :boolean, %w[skip-ci] => :boolean, %w[local-ci -l] => :boolean
  desc "deploy [TO=production]", "checks that current branch is a ff with master, checks with ci, merges into master, deploys to target, and then deletes branch."
  def deploy to=nil
    branch = Git.current_branch

    if branch == "master"
      run_crucial "git push origin master:master"
      invoke :ci, [branch], options.slice("local-ci") unless options["skip-ci"]

    else
      run_crucial "git fetch origin master:master"

      unless Git.fast_forward_merge?("origin/master", branch)
        puts "The master branch has advanced. Attempting rebase..."
        run_crucial "git rebase origin/master"
      end

      run_crucial "git push -f origin #{branch}:#{branch}"

      invoke :ci, [branch], options.slice("local-ci") unless options["skip-ci"]

      run_crucial "git push origin #{branch}:master"
      run_crucial "git fetch origin master:master"
    end

    if `git remote` =~ /\bgithub\b/
      run_crucial "git push github"
    end

    to ||= @config.servers.key?(:production) ? :production : :staging

    command = "git pull origin master && bin/setup"
    run_crucial ssh_command(to, command)

    puts green("Deploy Succeeded")

    if branch != "master"
      puts "Deleting branch: #{branch}"
      run_crucial "git push --delete origin #{branch}"

      if branch == Git.current_branch
        run_crucial "git checkout master"
      end

      run_crucial "git branch -D #{branch}"
    end

    ping to
  end

  method_options %w[verbose -v] => :boolean, %w[local-ci -l] => :boolean
  desc "ci [BRANCH=HEAD]", "runs ci against BRANCH"
  def ci branch=Git.current_branch
    ci = CI.new(project_name, `git rev-parse #{branch}`.chomp, local: options["local-ci"])
    if ci.exists?
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
        if !options["local-ci"] && File.exist?("coverage")
          puts "Downloading test coverage from CI..."
          download_ci_test_coverage
        end
        puts "Deploying..."
      else
        puts
        puts ci.last_response
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

  desc "open [SERVER=production]", "opens the url in the web browser."
  def open server=nil
    server ||= @config.servers.key?(:production) ? :production : :staging
    server = @config.servers[server.to_sym]
    exec "xdg-open #{server.default_ping}"
  end

  desc "hurt", "reruns a command until it fails"
  def hurt *args
    1.upto(Float::INFINITY) do |count|
      puts "Running attempt #{count}"
      system *args
      unless $?.success?
        puts "Ran #{count-1} times before failing"
        break
      end
    end
  end

  method_options %w[home] => :boolean
  desc "ssh [TO=production]", "logs into the specified server via SSH"
  def ssh to=:production
    command = "exec $SHELL -l"
    if to == "gubs" && !options["home"]
      server = @config.servers[:gubs]
      command = %(bash -lic "exec ./vagrant \\"cd #{server.path} && #{command}\\"")
      exec ssh_command(to, command, home: true)
    else
      exec ssh_command(to, command, home: options["home"])
    end
  end

  desc "install", "copies bin/setup and bin/ci scripts into current project."
  def install
    install_files_path = File.expand_path(File.join(__dir__, "../install_files/*"))
    system "cp #{install_files_path} bin/"
  end

  desc "ping [SERVER=production]", "hits the server over http to verify that its up."
  def ping server=:production
    server = @config.servers[server.to_sym]
    return false if server.ping == false

    url = server.default_ping
    if server.ping =~ %r{^/}
      url += server.ping
    elsif server.ping.to_s.length > 0
      url = server.ping
    end

    command = "curl -sfL #{url} 2>&1 1>/dev/null"
    unless system command
      puts "#{server.to_s.capitalize} is down!"
      exit 1
    end
  end

  desc "master_key [FROM=production, TO=local]", "copy master key from FROM to TO"
  def master_key from="production", to="local"
    if to == "local"
      copy :from, from, "config/master.key"
    end
    if from == "local"
      copy :to, to, "config/master.key"
    end
  end

  desc "download_ci_test_coverage", "download latest test coverage information from CI"
  def download_ci_test_coverage
    rsync :from, :ci, "coverage"
  end
end

