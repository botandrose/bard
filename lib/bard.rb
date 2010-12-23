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
    run_crucial "rake bootstrap:test", options.verbose?
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

    if `curl -s -I --user botandrose:thecakeisalie http://integrity.botandrose.com/#{project_name}` !~ /\bStatus: 404\b/
      puts "Integrity: verifying build..."
      system "curl -sX POST --user botandrose:thecakeisalie http://integrity.botandrose.com/#{project_name}/builds"
      while true
        response = `curl -s --user botandrose:thecakeisalie http://integrity.botandrose.com/#{project_name}`
        break unless response =~ /div class='(building|pending)' id='last_build'/
        sleep(2)
      end
      case response
        when /div class='failed' id='last_build'/ then raise TestsFailedError
        when /div class='success' id='last_build'/ then puts "Integrity: success! deploying to production"
        else raise "Unknown response from CI server:\n#{response}"
      end
    end

    run_crucial "cap deploy", options.verbose?

    puts green("Deploy Succeeded")
  end

  private
    def ensure_sanity!(dirty_ok = false)
      auto_update!
      check_dependencies
      raise NotInProjectRootError unless File.directory? ".git"
      raise OnMasterBranchError if current_branch == "master"
      raise WorkingTreeDirtyError unless `git status`.include? "working directory clean" unless dirty_ok
    end
end
