class Bard < Thor
  {
    "SubmoduleDirtyError"       => "You have uncommitted changes to a submodule!\n  Please see Micah about this.",
    "SubmoduleUnpushedError"    => "You have unpushed changes to a submodule!\n  Please see Micah about this.",
    "NonFastForwardError"       => "Someone has pushed some changes since you last pulled.\n  Kindly run bard pull, ensure that your your changes still work, and try again",
    "MasterNonFastForwardError" => "The master branch has advanced since last deploy, probably due to a bugfix.\n  Rebase your integration branch on top of it, and check for breakage.",
    "NotInProjectRootError"     => "You are not in the project's root directory!",
    "NotOnIntegrationError"     => "You are not on the integration branch!\n  Type `git checkout integration` to switch to it. If you have made changes to your current branch, please see Micah for assistance.",
    "WorkingTreeDirtyError"     => "You have uncommitted changes!\n  Please run git commit before attempting to push or pull.",
    "StagingDetachedHeadError"  => "The staging server is on a detached HEAD!\n  Please see Micah for assistance.",
    "TestsFailedError"          => "Automated tests failed!\n  See http://integrity.botandrose.com/ for more info."
  }.each do |error, message|
    eval <<-RUBY
    class #{error} < Bard::Error
      def message
        %q{#{message}}
      end
    end
  RUBY
  end
end
