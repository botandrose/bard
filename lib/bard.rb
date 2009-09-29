$:.unshift File.expand_path(File.dirname(__FILE__))
require 'term/ansicolor'
require 'systemu'
require 'grit'

require 'bard/git'
require 'bard/io'

class Bard < Thor
  include BardGit
  include BardIO

  desc "pull", "pull changes to your local machine"
  def pull
    ensure_integration_branch!
    ensure_clean_working_directory!

    unless fast_forward_merge?
      warn "Someone has pushed some changes since you last pulled.\n  Please ensure that your changes didnt break stuff."
    end

    run_crucial "git pull --rebase origin integration"

    changed_files = `git diff #{@common_ancestor} origin/integration --diff-filter=ACDMR --name-status`.split("\n") 
   
    if changed_files.any? { |f| f =~ %r(\bdb/migrate/.+) }
      run_crucial "rake db:migrate"
      run_crucial "rake db:migrate RAILS_ENV=test"
    end
     
    if changed_files.any? { |f| f =~ %r(\b.gitmodules\b) }
      run_crucial "git submodule sync"
      run_crucial "git submodule init"
    end
    run_crucial "git submodule update"
   
    if changed_files.any? { |f| f =~ %r(\bconfig/environment\b) }
      run_crucial "rake gems:install"
    end

    run_crucial "touch tmp/restart.txt"
  end

  desc "push", "push local changes out to the remote"
  def push
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

    run_crucial "git push origin integration"
    
    # TODO
    #stage
  end
end
