class Bard::CLI < Thor
  class NonFastForwardError < Bard::CLI::Error
    def message
      "Someone has pushed some changes since you last pulled.\n  Kindly run bard pull, ensure that your your changes still work, and try again"
    end
  end

  class MasterNonFastForwardError < Bard::CLI::Error
    def message
      "The master branch has advanced since last deploy, probably due to a bugfix.\n  Rebase your branch on top of it, and check for breakage."
    end
  end
end

