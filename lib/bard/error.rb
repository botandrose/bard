class Bard < Thor
  {
    "NonFastForwardError"       => "Someone has pushed some changes since you last pulled.\n  Kindly run bard pull, ensure that your your changes still work, and try again",
    "MasterNonFastForwardError" => "The master branch has advanced since last deploy, probably due to a bugfix.\n  Rebase your integration branch on top of it, and check for breakage.",
    "NotInProjectRootError"     => "You are not in the project's root directory!",
    "OnMasterBranchError"       => "You are on the master branch!\n  This is almost always a bad idea. Please work on a topic branch. If you have made changes on this branch, please see Micah for assistance.",
    "WorkingTreeDirtyError"     => "You have uncommitted changes!\n  Please run git commit before attempting to push or pull.",
    "StagingDetachedHeadError"  => "The staging server is on a detached HEAD!\n  Please see Micah for assistance."
  }.each do |error, message|
    eval <<-RUBY
    class #{error} < Bard::Error
      def message
        %q{#{message}}
      end
    end
  RUBY
  end
  
  class TestsFailedError < Bard::Error
    def message
      "Automated tests failed!\n  See #{super} for more info."
    end
  end

  class TestsAbortedError < Bard::Error
    def message
      "Automated tests aborted!\n  See #{super} for more info."
    end
  end
end
