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

require 'bard/check'
require 'bard/ssh_delegation'

class Bard < Thor
  include BardGit
  include BardIO

  VERSION = File.read(File.expand_path(File.dirname(__FILE__) + "../../VERSION")).chomp

  method_options %w( verbose -v ) => :boolean

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
    
    # git post-receive hook runs stage task below
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

    run_crucial "cap ROLES=staging COMMAND='cd #{project_name} && cap deploy' invoke"
  end

  if ENV['RAILS_ENV'] == "staging"
    desc "stage", "!!! INTERNAL USE ONLY !!! reset HEAD to integration, update submodules, run migrations, install gems, restart server"
    def stage
      check_dependencies

      if ENV['GIT_DIR'] == '.'
        # this means the script has been called as a hook, not manually.
        # get the proper GIT_DIR so we can descend into the working copy dir;
        # if we don't then `git reset --hard` doesn't affect the working tree.
        Dir.chdir '..' 
        ENV['GIT_DIR'] = '.git'
      end

      raise StagingDetachedHeadError unless current_branch
      old_rev, new_rev, branch = gets.split(' ') # get the low down about the commit from the git hook

      if current_branch == branch.split('/').last
        run_crucial "git reset --hard"
        prepare_environment changed_files(old_rev, new_rev)
      end
    end
  end

  private
    def ensure_sanity!
      check_dependencies
      raise NotInProjectRootError unless File.directory? ".git"
      raise NotOnIntegrationError unless current_branch == "integration"
      raise WorkingTreeDirtyError unless `git status`.include? "working directory clean"
    end

    def prepare_environment(changed_files)
      if changed_files.any? { |f| f =~ %r(^db/migrate/.+) }
        run_crucial "rake db:migrate"
        run_crucial "rake db:migrate RAILS_ENV=test"
      end
       
      run_crucial "git submodule sync"
      run_crucial "git submodule update --merge"
      if `git submodule` =~ /^[^ ]/
        run_crucial "git submodule update --init"
      end
      run_crucial "git submodule foreach 'git reset --hard'"
     
      if changed_files.any? { |f| f =~ %r(^config/environment.+) }
        run_crucial "rake gems:install"
      end

      system "touch tmp/restart.txt"
    end
end
