module Bard::CLI::Vim
  def self.included mod
    mod.class_eval do

      desc "vim [branch=master]", "open all files that have changed since master"
      def vim branch="master"
        exec "vim -p `(git diff #{branch} --name-only; git ls-files --others --exclude-standard) | grep -v '^app/assets/images/' | grep -v '^app/assets/stylesheets/' | while read f; do [ -f \"$f\" ] && ! file -b \"$f\" | grep -q \"binary\" && echo \"$f\"; done | tac`"
      end

    end
  end
end

