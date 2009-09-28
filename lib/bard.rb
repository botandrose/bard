require 'systemu'
require 'grit'

class Bard < Thor
  desc "pull", "pull changes to your local machine"
  def pull
    ensure_integration_branch!

    unless `git name-rev --name-only HEAD`.chomp == "integration"
      fatal "You are not on the integration branch! Type `git checkout integration` to switch to it. If you have made changes to your current branch, please see Micah for assistance."
    end

    unless `git status`.include? "working directory clean"
      fatal "Cannot upload changes: You have uncommitted changes!\n  Please run git commit before attempting to push."
    end

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
    unless `git name-rev --name-only HEAD`.chomp == "integration"
      fatal "You are not on the integration branch! Type `git checkout integration` to switch to it. If you have made changes to your current branch, please see Micah for assistance."
    end

    unless `git status`.include? "working directory clean"
      fatal "Cannot upload changes: You have uncommitted changes!\n  Please run git commit before attempting to push."
    end

    if submodule_dirty?
      fatal "Cannot upload changes: You have uncommitted changes to a submodule!\n  Please see Micah about this."
    end

    if submodule_unpushed?
      fatal "Cannot upload changes: You have unpushed changes to a submodule!\n  Please see Micah about this."
    end

    unless fast_forward_merge?
      fatal "Someone has pushed some changes since you last pulled.\n  Kindly run bard pull, ensure that your your changes still work.\n  Then run bard push again"
    end

    run_crucial "git push origin integration"
    
    # TODO
    #stage
  end

  private
    def ensure_integration_branch!
      unless `git name-rev --name-only HEAD`.chomp == "integration"
        fatal "You are not on the integration branch! Type `git checkout integration` to switch to it. If you have made changes to your current branch, please see Micah for assistance."
      end
    end

    def fast_forward_merge? 
      run_crucial "git fetch origin"
      head = run_crucial "git rev-parse HEAD"
      remote_head = run_crucial "git rev-parse origin/integration"
      common_ancestor = find_common_ancestor head, remote_head
      common_ancestor == remote_head
    end

    def find_common_ancestor(head1, head2)
      run_crucial "git merge-base #{head1} #{head2}"
    end

    def submodule_dirty?
      @repo ||= Grit::Repo.new "."
      submodules = Grit::Submodule.config(@repo, @repo.head.name)
      submodules.any? do |name, submodule|
        Dir.chdir submodule["path"] do
          not `git status`.include? "working directory clean"
        end
      end
    end

    def submodule_unpushed?
      @repo ||= Grit::Repo.new "."
      submodules = Grit::Submodule.config(@repo, @repo.head.name)
      submodules.any? do |name, submodule|
        Dir.chdir submodule["path"] do
          branch = `git name-rev --name-only HEAD`.chomp
          `git fetch`
          submodule["id"] != `git rev-parse origin/#{branch}`.chomp
        end
      end
    end

    RED     = "\033[1;31m"
    YELLOW  = "\033[1;33m"
    GREEN   = "\033[1;32m"    
    DEFAULT = "\033[0m"

    def warn(message)
      $stderr.puts "#{YELLOW}!!!#{DEFAULT} #{message}"
    end

    def fatal(message)
      raise Thor::Error, "#{RED}!!!#{DEFAULT} #{message}"
    end

    def run_crucial(command)
      status, stdout, stderr = systemu command
      fatal "Running command: #{YELLOW}#{command}#{DEFAULT}: #{stderr}" if status.to_i.nonzero?
      stdout.chomp
    end
end
