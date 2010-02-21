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

  method_options %w( verbose -v ) => :boolean

  desc "create [PROJECT_NAME]", "create new project"
  def create(project_name)
    template_path = File.expand_path(File.dirname(__FILE__) + "/bard/template.rb")
    command = "rails --template=#{template_path} #{project_name}"
    exec command
  end

  desc "check [PROJECT_PATH]", "check current project and environment for missing dependencies and common problems"
  def check(project_path = nil)
    project_path = "." if project_path.nil? and File.directory? ".git" and File.exist? "config/environment.rb"
    check_dependencies
    check_project project_path if project_path
  end

  desc "pull", "pull changes to your local machine"
  def pull
    ensure_sanity!

    warn NonFastForwardError unless fast_forward_merge?

    run_crucial "git pull --rebase origin integration"

    prepare_environment changed_files(@common_ancestor, "origin/integration")
  end

  desc "push", "push local changes out to the remote"
  def push
    ensure_sanity!

    raise SubmoduleDirtyError if submodule_dirty?
    raise SubmoduleUnpushedError if submodule_unpushed?
    raise NonFastForwardError unless fast_forward_merge?

    run_crucial "git push origin integration", true
    
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

    if `curl -s -I http://integrity.botandrose.com/#{project_name}` !~ /\b404\b/
      puts "Integrity: verifying build..."
      system "curl -sX POST http://integrity.botandrose.com/#{project_name}/builds"
      while true
        response = `curl -s http://integrity.botandrose.com/#{project_name}`
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
    check_dependencies

    ENV['RAILS_ENV'] = "staging"
    run_crucial "git fetch"
    run_crucial "git reset --hard origin/integration"
    prepare_environment
  end

  private
    def ensure_sanity!
      check_dependencies
      raise NotInProjectRootError unless File.directory? ".git"
      raise NotOnIntegrationError unless current_branch == "integration"
      raise WorkingTreeDirtyError unless `git status`.include? "working directory clean"
    end

    def prepare_environment(changed_files = nil)
      if changed_files.nil? or changed_files.any? { |f| f =~ %r(^config/environment.+) }
        run_crucial "rake gems:install"
      end
     
      if changed_files.nil? or changed_files.any? { |f| f =~ %r(^db/migrate/.+) }
        run_crucial "rake db:migrate"
        run_crucial "rake db:migrate RAILS_ENV=test" unless ENV['RAILS_ENV'] == 'staging'
      end
       
      run_crucial "git submodule sync"
      run_crucial "git submodule init"
      run_crucial "git submodule update --merge"
      run_crucial "git submodule foreach 'git checkout `git name-rev --name-only HEAD`'"

      system "touch tmp/restart.txt"
    end
end
