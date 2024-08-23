module Bard::CLI::Vim
  def self.included mod
    mod.class_eval do

      desc "vim [branch=master]", "open all files that have changed since master"
      def vim branch="master"
        exec "vim -p `git diff #{branch} --name-only | grep -v sass$ | tac`"
      end

    end
  end
end

