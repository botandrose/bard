module Bard
  class Bugfix < Thor
    desc "new BUGFIX_BRANCH_NAME", "branch off of production to begin a time-sensitive bugfix."
    def new(branch_name)
      system "git fetch origin"
      system "git checkout -b bugfix-#{branch_name} origin/master"
    end
  end
end
