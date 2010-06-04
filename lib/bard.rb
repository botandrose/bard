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
    
    run_crucial_via_bard "bard stage"
  end

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

    run_crucial_via_bard "cap deploy"
  end

  desc "stage", "!!! INTERNAL USE ONLY !!! reset HEAD to integration, update submodules, run migrations, install gems, restart server"
  def stage
    ensure_sanity!(true)

    run_crucial "git fetch"
    run_crucial "git checkout master && git reset --hard origin/master"
    run_crucial "git checkout integration && git reset --hard origin/integration"
    run_crucial "rake bootstrap RAILS_ENV=staging"
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
