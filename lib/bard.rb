$:.unshift File.expand_path(File.dirname(__FILE__))
require 'term/ansicolor'
require 'net/http'
require 'systemu'
require 'grit'
require 'thor'

require 'bard/git'
require 'bard/io'

require 'bard/check'

class Bard < Thor
  include BardGit
  include BardIO

  VERSION = File.read(File.expand_path(File.dirname(__FILE__) + "../../VERSION")).chomp

  method_options %w( verbose -v ) => :boolean

  desc "check [PROJECT_PATH]", "check current project and environment for missing dependencies and common problems"
  def check(project_path = nil)
    project_path = "." if project_path.nil? and File.directory? ".git"
    check_dependencies
    check_project project_path if project_path
  end

  desc "pull", "pull changes to your local machine"
  def pull
    check_dependencies

    ensure_project_root!
    ensure_integration_branch!
    ensure_clean_working_directory!

    unless fast_forward_merge?
      warn "Someone has pushed some changes since you last pulled.\n  Please ensure that your changes didnt break stuff."
    end

    run_crucial "git pull --rebase origin integration"

    changed_files = run_crucial("git diff #{@common_ancestor} origin/integration --diff-filter=ACDMR --name-only").split("\n") 
   
    if changed_files.any? { |f| f =~ %r(^db/migrate/.+) }
      run_crucial "rake db:migrate"
      run_crucial "rake db:migrate RAILS_ENV=test"
    end
     
    if changed_files.any? { |f| f == ".gitmodules" }
      run_crucial "git submodule sync"
      run_crucial "git submodule init"
    end
    run_crucial "git submodule update --merge"
    run_crucial "git submodule foreach 'git reset --hard'"
   
    if changed_files.any? { |f| f =~ %r(^config/environment.+) }
      run_crucial "rake gems:install"
    end

    system "touch tmp/restart.txt"
  end

  desc "push", "push local changes out to the remote"
  def push
    check_dependencies

    ensure_project_root!
    ensure_integration_branch!
    ensure_clean_working_directory!

    if submodule_dirty?
      fatal "Cannot push changes: You have uncommitted changes to a submodule!\n  Please see Micah about this."
    end

    if submodule_unpushed?
      fatal "Cannot push changes: You have unpushed changes to a submodule!\n  Please see Micah about this."
    end

    unless fast_forward_merge?
      fatal "Someone has pushed some changes since you last pulled.\n  Kindly run bard pull, ensure that your your changes still work.\n  Then run bard push again."
    end

    run_crucial "git push origin integration", true
    
    # git post-receive hook runs stage task below
  end

  desc "deploy", "pushes, merges integration branch into master and deploys it to production"
  def deploy
    invoke :push

    run_crucial "git fetch origin"
    run_crucial "git checkout master"
    run_crucial "git pull --rebase origin master"
    if not fast_forward_merge? "master", "integration"
      fatal "master has advanced since last deploy, probably due to a bugfix. rebase your integration branch on top of it, and check for breakage."
    end

    run_crucial "git merge integration"
    run_crucial "git push origin master"
    run_crucial "git checkout integration"
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

      run_crucial "git reset --hard"

      # find out the current branch
      head = File.read('.git/HEAD').chomp
      # abort if we're on a detached head
      exit unless head.sub! 'ref: ', ''
      revs = gets.split ' '  
      old_rev, new_rev, branch = revs

      if branch == "master"
        run_crucial "cap deploy"
      elsif read == branch
        changed_files = run_crucial("git diff #{old_rev} #{new_rev} --diff-filter=ACMRD --name-only").split("\n") 

        if changed_files.any? { |f| f =~ %r(^db/migrate/.+) }
          run_crucial "rake db:migrate RAILS_ENV=staging"
          run_crucial "rake db:migrate RAILS_ENV=test"
        end
         
        if changed_files.any? { |f| f == ".gitmodules" }
          run_crucial "git submodule sync"
          run_crucial "git submodule init"
        end
        system "git submodule update"
       
        if changed_files.any? { |f| f =~ %r(^config/environment.+) }
          run_crucial "rake gems:install"
        end

        system "touch tmp/restart.txt"
      end
    end
  end
end
