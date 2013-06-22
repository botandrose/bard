$:.unshift File.expand_path(File.dirname(__FILE__))
require 'rubygems'
require 'term/ansicolor'
require 'net/http'
require 'systemu'
require 'grit'
require 'thor'

require 'bard/error'
require 'bard/git'
require 'bard/io'

require 'bard/ssh_delegation'

class Bard < Thor
  include BardGit
  include BardIO

  VERSION = File.read(File.expand_path(File.dirname(__FILE__) + "../../VERSION")).chomp

  desc "install [PROJECT NAME]", "install and bootstrap existing project"
  def install(project_name)
    auto_update!
    command = <<-BASH
    git clone git@git.botandrose.com:#{project_name}.git

    cd #{project_name}
    git checkout integration
    rvm . do bundle
    rvm . do bundle exec rake bootstrap

    sudo -s <#{"<EOF"}
      echo "<VirtualHost *:80>
        ServerName #{project_name}.local
        DocumentRoot `pwd`/public
</VirtualHost>" > /etc/apache2/sites-available/#{project_name}
      a2ensite #{project_name}
      apache2ctl restart

      if ! grep "#{project_name}.local" /etc/hosts; then
        echo 127.0.0.1 #{project_name}.local >> /etc/hosts
      fi
EOF
    BASH
    exec command
  end

  desc "data [FROM=production, TO=local]", "copy database and assets from FROM to TO"
  def data(from = "production", to = "local")
    ensure_sanity!(true)

    if to == "local"
      if from == "production" and heroku?
        exec "heroku db:pull --confirm #{project_name}"
      else
        exec "cap data:pull ROLES=#{from}"
      end

    else
      if from == "local"
        exec "cap data:push ROLES=#{to}"
      end
    end
  end

  method_options %w( verbose -v ) => :boolean
  desc "pull", "pull changes to your local machine"
  def pull
    ensure_sanity!

    warn NonFastForwardError unless fast_forward_merge?("origin/#{current_branch}")

    run_crucial "git pull --rebase origin #{current_branch}", options.verbose?
    run_crucial "bundle && bundle exec rake bootstrap", options.verbose?
  end

  method_options %w( verbose -v ) => :boolean
  desc "push", "push local changes out to the remote"
  def push
    ensure_sanity!

    raise NonFastForwardError unless fast_forward_merge?("origin/#{current_branch}")

    run_crucial "git push origin #{current_branch}", true
  end

  method_options %w( verbose -v ) => :boolean
  desc "stage", "pushes current branch, and stages it"
  def stage
    invoke :push

    run_crucial "cap stage BRANCH=#{current_branch}", options.verbose?

    puts green("Stage Succeeded")
  end

  method_options %w( verbose -v ) => :boolean
  desc "deploy", "pushes, merges integration branch into master and deploys it to production"
  def deploy
    invoke :push

    run_crucial "git fetch origin"
    run_crucial "git checkout master"
    run_crucial "git pull --rebase origin master"
    raise MasterNonFastForwardError if not fast_forward_merge? "master", "integration"

    run_crucial "git merge integration"
    run_crucial "git push origin master"
    run_crucial "git checkout integration"

    invoke :ci

    if heroku?
      run_crucial "git push production", options.verbose?
      run_crucial "heroku run rake bootstrap:production:post", options.verbose?
    else
      run_crucial "cap deploy", options.verbose?
    end

    puts green("Deploy Succeeded")
  end

  method_options %w( verbose -v ) => :boolean
  desc "ci", "runs ci against master branch"
  def ci
    return unless has_ci?

    puts "Continuous integration: starting build..."
    last_build_number = get_last_build_number
    last_time_elapsed = get_last_time_elapsed
    start_ci
    sleep(2) while last_build_number == get_last_build_number

    start_time = Time.new.to_i
    while (response = `curl -s #{ci_host}/lastBuild/api/xml?token=botandrose`).include? "<building>true</building>"
      elapsed_time = Time.new.to_i - start_time
      if last_time_elapsed
        percentage = (elapsed_time.to_f / last_time_elapsed.to_f * 100).to_i
        output = "  Estimated completion: #{percentage}%"
      else
        output = "  No estimated completion time. Elapsed time: #{elapsed_time} sec"
      end
      print "\x08" * output.length
      print output
      $stdout.flush
      sleep(2)
    end
    puts

    case response
      when /<result>FAILURE<\/result>/ then 
        puts
        puts `curl -s #{ci_host}/lastBuild/console?token=botandrose`.match(/<pre>(.+)<\/pre>/m)[1]
        puts
        raise TestsFailedError, "#{ci_host}/#{get_last_build_number}/console"

      when /<result>ABORTED<\/result>/ then 
        raise TestsAbortedError, "#{ci_host}/#{get_last_build_number}/console"

      when /<result>SUCCESS<\/result>/ then
        puts "Continuous integration: success! deploying to production"

      else raise "Unknown response from CI server:\n#{response}"
    end
  end

  private
    def heroku?
      `git remote -v`.include? "production\tgit@heroku.com:"
    end

    def ci_host
      "http://botandrose:thecakeisalie!@ci.botandrose.com/job/#{project_name}"
    end

    def has_ci?
      `curl -s -I #{ci_host}/?token=botandrose` =~ /\b200 OK\b/
    end

    def start_ci
      `curl -s -I -X POST #{ci_host}/build?token=botandrose`
    end

    def get_last_build_number
      response = `curl -s #{ci_host}/lastBuild/api/xml?token=botandrose`
      response.match(/<number>(\d+)<\/number>/)
      $1 ? $1.to_i : nil
    end

    def get_last_time_elapsed
      response = `curl -s #{ci_host}/lastStableBuild/api/xml?token=botandrose`
      response.match(/<duration>(\d+)<\/duration>/)
      $1 ? $1.to_i / 1000 : nil
    end

    def ensure_sanity!(dirty_ok = false)
      auto_update!
      raise NotInProjectRootError unless File.directory? ".git"
      raise OnMasterBranchError if current_branch == "master"
      raise WorkingTreeDirtyError unless `git status`.include? "working directory clean" unless dirty_ok
    end

    def auto_update!
      match = `curl -s http://rubygems.org/api/v1/gems/bard.json`.match(/"version":"([0-9.]+)"/)
      return unless match
      required = match[1]
      if Bard::VERSION != required
        original_command = [ENV["_"], @_invocations[Bard].first, ARGV].flatten.join(" ")
        puts "bard gem is out of date... updating to new version"
        exec "gem install bard && #{original_command}"
      end
      if options.verbose?
        puts green("#{"bard".ljust(9)} (#{Bard::VERSION})") 
      end
    end
end

