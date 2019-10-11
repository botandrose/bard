module Bard; end

require "bard/base"
require "bard/git"
require "bard/ci"
require "bard/config"

class Bard::CLI < Thor
  def initialize(*args, **kwargs, &block)
    super
    @config = Config.new(project_name, "bard.rb")
  end

  desc "data [FROM=production, TO=local]", "copy database and assets from FROM to TO"
  def data(from="production", to="local")
    if to == "local"
      data_pull_db from.to_sym
      data_pull_assets from.to_sym
    end
    if from == "local"
      data_push_db to.to_sym
      data_push_assets to.to_sym
    end
  end

  desc "data_pull_db FROM", "copy database down from server"
  def data_pull_db server
    run_crucial ssh_command(server, "bin/rake db:dump && gzip -9f db/data.sql")
    copy :from, server, "db/data.sql.gz"
    run_crucial "gunzip -f db/data.sql.gz && bin/rake db:load"
  end

  desc "data_push_db TO", "copy database up to server"
  def data_push_db server
    run_crucial "bin/rake db:dump && gzip -9f db/data.sql"
    copy :to, server, "db/data.sql.gz"
    run_crucial ssh_command(server, "gunzip -f db/data.sql.gz && bin/rake db:load")
  end

  desc "data_pull_assets FROM", "copy file assets down from server"
  def data_pull_assets server
    @config.data.each do |path|
      rsync :from, server, path
    end
  end

  desc "data_push_assets FROM", "copy file assets up to server"
  def data_push_assets server
    @config.data.each do |path|
      rsync :to, server, path
    end
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

  method_options %w( verbose -v ) => :boolean, %w( skip-ci ) => :boolean
  desc "deploy [BRANCH=HEAD]", "checks that branch is a ff with master, checks with ci, and then merges into master and deploys to production, and deletes branch."
  def deploy branch=Git.current_branch
    if branch == "master"
      run_crucial "git push origin master:master"
      invoke :ci unless options["skip-ci"]

    else
      run_crucial "git fetch origin master:master"

      unless Git.fast_forward_merge?("origin/master", branch)
        puts "The master branch has advanced. Attempting rebase..."
        run_crucial "git rebase origin/master"
      end

      run_crucial "git push -f origin #{branch}:#{branch}"

      invoke :ci unless options["skip-ci"]

      run_crucial "git push origin #{branch}:master"
      run_crucial "git fetch origin master:master"
    end

    if `git remote` =~ /\bgithub\b/
      run_crucial "git push github"
    end

    to = @config.servers.key?(:production) ? :production : :staging
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

  method_options %w( verbose -v ) => :boolean
  desc "ci [BRANCH=HEAD]", "runs ci against BRANCH"
  def ci branch=Git.current_branch
    ci = CI.new(project_name, `git rev-parse #{branch}`.chomp)
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
        if File.exist?("coverage")
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
    command = "bash -lic 'exec ./vagrant \'#{command}\''" if to == "gubs"
    exec ssh_command(to, command, home: options["home"])
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

  desc "push_master_key", "copy master key to server"
  def push_master_key server
    copy :to, server, "config/master.key"
  end

  desc "pull_master_key", "copy master key from server"
  def pull_master_key server
    copy :from, server, "config/master.key"
  end

  desc "download_ci_test_coverage", "download latest test coverage information from CI"
  def download_ci_test_coverage
    rsync :from, :ci, "coverage ./"
  end

  private

  def ssh_command server, command, home: false
    server = @config.servers[server.to_sym]
    uri = URI.parse("ssh://#{server.ssh}")
    command = "cd #{server.path} && #{command}" unless home
    command = "ssh -tt #{"-p#{uri.port} " if uri.port}#{uri.user}@#{uri.host} '#{command}'"
    if server.gateway
      uri = URI.parse("ssh://#{server.gateway}")
      command = "ssh -tt #{" -p#{uri.port} " if uri.port}#{uri.user}@#{uri.host} \"#{command}\""
    end
    command
  end

  def copy direction, server, path
    server = @config.servers[server.to_sym]

    uri = URI.parse("ssh://#{server.gateway}")
    port = uri.port ? "-p#{uri.port}" : ""
    gateway = server.gateway ? "-oProxyCommand='ssh #{port} #{uri.user}@#{uri.host} -W %h:%p'" : ""

    uri = URI.parse("ssh://#{server.ssh}")
    port = uri.port ? "-P#{uri.port}" : ""
    from_and_to = [path, "#{uri.user}@#{uri.host}:#{server.path}/#{path}"]

    from_and_to.reverse! if direction == :from
    command = "scp #{gateway} #{port} #{from_and_to.join(" ")}"

    run_crucial command
  end

  def rsync direction, server, path
    server = @config.servers[server.to_sym]

    uri = URI.parse("ssh://#{server.gateway}")
    port = uri.port ? "-p#{uri.port}" : ""
    gateway = server.gateway ? "-oProxyCommand=\"ssh #{port} #{uri.user}@#{uri.host} -W %h:%p\"" : ""

    uri = URI.parse("ssh://#{server.ssh}")
    port = uri.port ? "-p#{uri.port}" : ""
    ssh = "-e'ssh #{port} #{gateway}'"

    dest_path = path.dup
    dest_path.sub! %r(/[^/]+$), '/'
    from_and_to = [dest_path, "#{uri.user}@#{uri.host}:#{project_name}/#{path}"]

    from_and_to.reverse! if direction == :from
    command = "rsync #{ssh} --delete -avz #{from_and_to.join(" ")}"

    run_crucial command
  end
end

