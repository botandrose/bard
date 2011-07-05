$:.unshift File.expand_path(File.dirname(__FILE__))
require 'rubygems'
require 'term/ansicolor'
require 'net/http'
require 'systemu'
require 'versionomy'
require 'grit'
require 'thor'

require 'bard/error'
require 'bard/git'
require 'bard/io'

require 'bard/check'
require 'bard/ssh_delegation'

class Bard < Thor
  include BardGit
  include BardIO

  VERSION = File.read(File.expand_path(File.dirname(__FILE__) + "../../VERSION")).chomp

  desc "create [PROJECT_NAME]", "create new project"
  def create(project_name)
    auto_update!
    check_dependencies
    template_path = File.expand_path(File.dirname(__FILE__) + "/bard/template.rb")
    command = "rails --template=#{template_path} #{project_name}"
    exec command
  end

  method_options %w( verbose -v ) => :boolean
  desc "check [PROJECT_PATH]", "check current project and environment for missing dependencies and common problems"
  def check(project_path = nil)
    project_path = "." if project_path.nil? and File.directory? ".git" and File.exist? "config/environment.rb"
    auto_update!
    check_dependencies
    check_project project_path if project_path
  end

  desc "data [ROLE=production]", "copy database and assets down to your local machine from ROLE"
  def data(role = "production")
    ensure_sanity!(true)
    exec "cap data:pull ROLES=#{role}"
  end

  method_options %w( verbose -v ) => :boolean
  desc "pull", "pull changes to your local machine"
  def pull
    ensure_sanity!

    warn NonFastForwardError unless fast_forward_merge?("origin/#{current_branch}")

    run_crucial "git pull --rebase origin #{current_branch}", options.verbose?
    run_crucial "bundle && bundle exec rake bootstrap:test", options.verbose?
  end

  method_options %w( verbose -v ) => :boolean
  desc "push", "push local changes out to the remote"
  def push
    ensure_sanity!

    raise SubmoduleDirtyError if submodule_dirty?
    raise SubmoduleUnpushedError if submodule_unpushed?
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
      percentage = (elapsed_time.to_f / last_time_elapsed.to_f * 100).to_i
      output = "  Estimated completion: #{percentage}%"
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
      response.match(/<number>(\d+)<\/number>/)[1].to_i
    end

    def get_last_time_elapsed
      response = `curl -s #{ci_host}/lastStableBuild/api/xml?token=botandrose`
      response.match(/<duration>(\d+)<\/duration>/)[1].to_i / 1000
    end

    def ensure_sanity!(dirty_ok = false)
      auto_update!
      check_dependencies
      raise NotInProjectRootError unless File.directory? ".git"
      raise OnMasterBranchError if current_branch == "master"
      raise WorkingTreeDirtyError unless `git status`.include? "working directory clean" unless dirty_ok
    end
end
