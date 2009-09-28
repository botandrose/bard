require 'systemu'

module Bard

  class Bugfix < Thor
    desc "new <bugfix_branch_name>", "branch off of production to begin a time-sensitive bugfix."
    def new(branch_name)
      unless `git status`.include? "working directory clean"
        fatal "Cannot create new bugfix branch: You have uncommitted changes!"
      end
      run_crucial "git fetch origin"
      run_crucial "git checkout -b bugfix-#{branch_name} origin/master"
    end

    private

      GREEN = "\033[1;32m"    
      RED = "\033[1;31m"
      DEFAULT = "\033[0m"

      def fatal(message)
        raise Thor::Error, "#{RED}!!!#{DEFAULT} #{message}"
      end

      def run_crucial(command)
        status, stdout, stderr = systemu command
        fatal stderr if status.to_i.nonzero?
      end

  end

end
