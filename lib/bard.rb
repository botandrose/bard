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
    run_crucial "git submodule init"
    run_crucial "git submodule sync"
    run_crucial "git submodule update"
    
    # TODO
    #migrate database
    #install gems
    #restart
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
