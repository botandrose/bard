require 'systemu'
require 'grit'

module Bard
  class Push < Thor::Group
    desc "upload local changes onto the integration branch"
    def push
      unless `git status`.include? "working directory clean"
        fatal "Cannot upload blah blah: You have uncommitted changes!"
      end

      unless fast_forward_merge?
        fatal "Someone has pushed some changes since you last pulled.\n  Kindly run bard pull, ensure that your your changes still work.\n  Then run bard push again"
      end

      run_crucial "git push origin integration"

    end

    private
      def fast_forward_merge? 
        run_crucial "git fetch origin"
        repo = Grit::Repo.new "."
        remote_integration_head = repo.remotes.find { |r| r.name == "origin/integration" }
        common_ancestor = find_common_ancestor repo.heads.first.commit.id, remote_integration_head.commit.id
        common_ancestor == remote_integration_head.commit.id
      end

      def find_common_ancestor(head1, head2)
        run_crucial("git merge-base #{head1} #{head2}").chomp
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

module BardError
  GREEN = "\033[1;32m"    
  RED = "\033[1;31m"
  DEFAULT = "\033[0m"

  def fatal(message)
    raise Thor::Error, "#{RED}!!!#{DEFAULT} #{message}"
  end

  def run_crucial(command)
    status, stdout, stderr = systemu command
    fatal stderr if status.to_i.nonzero?
    stdout
  end
end

Thor.class_eval do
  include BardError
end
Thor::Group.class_eval do
  include BardError
end
