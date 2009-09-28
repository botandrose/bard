require 'systemu'

module Bard
  class Pull < Thor::Group
    desc "pull integration branch changes to your local branch"
    def pull
      unless `git status`.include? "working directory clean"
        fatal "Cannot upload changes: You have uncommitted changes!\n  Please run git commit before attempting to push."
      end

      unless fast_forward_merge?
        warn "Someone has pushed some changes since you last pulled.\n  Please ensure that your changes didnt break stuff."
      end

      run_crucial "git pull --rebase origin integration"
      
      # TODO
      #submodule init sync update
      #migrate database
      #install gems
      #restart
    end
  end

  class Push < Thor::Group
    desc "upload local changes onto the integration branch"
    def push
      unless `git status`.include? "working directory clean"
        fatal "Cannot upload changes: You have uncommitted changes!\n  Please run git commit before attempting to push."
      end

      unless fast_forward_merge?
        fatal "Someone has pushed some changes since you last pulled.\n  Kindly run bard pull, ensure that your your changes still work.\n  Then run bard push again"
      end

      run_crucial "git push origin integration"
      
      # TODO
      #stage
    end
  end 

  class Bugfix < Thor
    desc "new <bugfix_branch_name>", "branch off of production to begin a time-sensitive bugfix."
    def new(branch_name)
      unless `git status`.include? "working directory clean"
        fatal "Cannot create new bugfix branch: You have uncommitted changes!"
      end
      run_crucial "git fetch origin"
      run_crucial "git checkout -b bugfix-#{branch_name} origin/master"
    end
  end

end

module BardGit
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
end

module BardError
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

Thor.class_eval do
  include BardError
  include BardGit
end
Thor::Group.class_eval do
  include BardError
  include BardGit
end
